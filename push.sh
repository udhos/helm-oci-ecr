#!/bin/bash

msg() {
    echo >&2 "$0: $@"
}

die() {
    msg "$@"
    exit 1
}

tmp_dir=tmp
chart_version=1.1.0
chart_url=https://udhos.github.io/miniapi/miniapi-${chart_version}.tgz
chart_file=$(basename $chart_url)
chart_path=$tmp_dir/$chart_file
ecr_repo_name=miniapi
region=us-east-1
image_version=1.0.6
image=udhos/miniapi:$image_version

#
# aws account id
#

msg "retrieving aws account id"
aws_account_id=$(aws sts get-caller-identity | jq -r .Account)
[ -n "$aws_account_id" ] || die "could not get aws account id"
msg aws_account_id=$aws_account_id

#
# download sample helm chart
#

msg "downloading chart $chart_url to $chart_path"

[ -d $tmp_dir ] || mkdir $tmp_dir || die "could not create dir" 
curl -s -o $chart_path $chart_url || die "could not download chart"

#
# create ecr repository
#

msg "creating ecr repository $ecr_repo_name"

aws ecr create-repository \
     --repository-name $ecr_repo_name \
     --region $region || die "could not create ecr repository"

#
# pull docker image
#

repo_url=$aws_account_id.dkr.ecr.$region.amazonaws.com/$ecr_repo_name
tag_full=$repo_url:$image_version

msg "pulling docker image $image"

docker pull $image
docker tag $image $tag_full

msg "docker logging into ecr"

ecr_login=$(aws ecr get-login-password --region $region)

echo $ecr_login |
    docker login \
        --username AWS \
        --password-stdin $aws_account_id.dkr.ecr.$region.amazonaws.com || die "could not login into ecr"

msg "pushing image into ecr: $tag_full"

docker push $tag_full

#
# create clean-up script
#

cat > $tmp_dir/cleanup.sh <<EOF
delete() {
    repo=\$1
    ids=\$(aws ecr list-images --region $region --repository-name \$repo --query 'imageIds[*]' --output json)

    aws ecr batch-delete-image --region $region \
        --repository-name \$repo \
        --image-ids "\$ids"

    aws ecr delete-repository --repository-name \$repo --region $region
}

delete $ecr_repo_name
EOF
chmod a+rx $tmp_dir/cleanup.sh

msg
msg "---------------------------------------------------------------------------"
msg "ATTENTION ATTENTION ATTENTION"
msg 
msg "remember to delete the ecr repository:"
msg
msg "$tmp_dir/cleanup.sh"
msg
msg "ATTENTION ATTENTION ATTENTION"
msg "---------------------------------------------------------------------------"
msg

#
# log into ecr
#

msg "helm logging into ecr"

echo $ecr_login | \
    helm registry login \
        --username AWS \
        --password-stdin $aws_account_id.dkr.ecr.$region.amazonaws.com || die "could not login into ecr"

#
# push chart
#

oci_url=oci://$aws_account_id.dkr.ecr.$region.amazonaws.com

msg "pushing helm chart $chart_path to $oci_url"

helm push $chart_path $oci_url

oci_full=$oci_url/$ecr_repo_name

#
# summary
#

msg
msg SUMMARY
msg
msg "image is at: $tag_full"
msg "        try: docker pull $tag_full"
msg
msg "chart is at: $oci_full"
msg "        try: helm show chart $oci_full --version $chart_version"
msg

#
# try these
#

msg
msg "try these:"
msg
msg helm show all $oci_full --version $chart_version
msg
msg helm pull $oci_full --version $chart_version
msg
msg helm template my-miniapi $oci_full --version $chart_version --set image.repository=$repo_url
msg
