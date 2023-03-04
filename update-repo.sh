#! /bin/bash

cd "$(dirname "$0")" || exit 1

# Check d-bus for notify-send
userid=$(id -u)
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$userid/bus"
export DBUS_SESSION_BUS_ADDRESS

# Check internet
status=$(curl -s -m 5 -IL google.com | grep 200)
if [ -z "$status" ]; then
	echo -e "\033[31mError: Check your network status.\033[0m"
	notify-send "cron job 'repo update' failed. Check your network status."
	exit 1
fi

# check teleBot
tele_send_py="$HOME/privacy/sentTotTeleBot/send.py"
tele_status="true"
if [ -f "$tele_send_py" ]; then
	if ! source "$HOME"/privacy/sentTotTeleBot/bin/activate; then
		tele_status="false"
		notify-send "Can not source $HOME/privacy/sentTotTeleBot/bin/activate"
	fi
else
	tele_status="false"
	notify-send "teleBot program($tele_send_py) does not exit."
	exit 1
fi

tele_send() {
	if [ $tele_status == "false" ]; then
		return
	fi
	python "$tele_send_py" "$1"
}

# Check path
download_path="$HOME/arch/RepoDB"
arch_repo_db_path="$HOME/arch/RepoDB"
arch_repo_name="LocalRepo"

if [ ! -d "$download_path" ]; then
	mkdir -p "$download_path"
fi

# Check remote_release info
remote_releases=$(gh api repos/{owner}/{repo}/releases)
if [ -z "$remote_releases" ]; then
	tele_send "get remote_release info failed."
	notify-send "get remote_release info failed."
	exit 1
fi

# Extract remote_release info and update
assets_names=$(echo "$remote_releases" | jq -cr '.[0].assets[] | .name')
flag="true"
json=$(cat pkg_info.json)
packages=$(echo "$json" | jq '.packages')
for package in $(echo "$packages" | jq -c '.[]'); do
	# local_version=$(paru -Qi "$pkg" | grep "^Version" | awk -F: '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
	pkg=$(echo "$package" | jq -r '.pkg')
	local_version=$(echo "$package" | jq -r '.version')

	suffix=pkg.tar.zst

	remote_asset_name=$(echo "$assets_names" | grep -o "^$pkg.*$suffix")

	if [ -z "$remote_asset_name" ]; then
		echo -e "\033[31mError: no asset found for package '$pkg'.\033[0m"
		tele_send "cron job 'repo update' failed. No asset found for package '$pkg'."
		notify-send "cron job 'repo update' failed. No asset found for package '$pkg'."
		sleep 2
		continue
	fi

	remote_version=${remote_asset_name#"$pkg"-}
	remote_version=${remote_version%-*}

	if [ "$remote_version" != "$local_version" ]; then
		echo -e "\033[1;32mUpdating \033[33m$pkg\033[1;32m from \033[1;33m$local_version\033[1;32m to \033[1;33m$remote_version\033[1;32m...\033[0m"

		if ! gh release download -p "$remote_asset_name" -D "$download_path" --skip-existing; then
			echo -e "\033[31mERROR: Download of asset '$remote_asset_name' failed\033[0m"
			tele_send "cron job 'repo update' failed. Download of asset '$remote_asset_name' failed."
			notify-send "cron job 'repo update' failed. Download of asset '$remote_asset_name' failed."
			flag="false"
		else
			json=$(echo "$json" | jq --arg pkg "$pkg" --arg version "$remote_version" '.packages |= map(if (.pkg == $pkg) then .version = $version else . end)')
			echo "$json" >pkg_info.json
			repo-add "$arch_repo_db_path/$arch_repo_name.db.tar.gz" "$download_path/$remote_asset_name"
		fi
	fi

	sleep 2
done

if [ $flag == "true" ]; then
	echo -e "\033[1;32mAll packages are up-to-date.\033[0m"
	tele_send "cron job 'repo update' has finished successfully"
	notify-send "cron job 'repo update' has finished successfully"
else
	tele_send "cron job 'repo update' finished with errors"
	notify-send "cron job 'repo update' finished with errors"
fi

git commit -am "update"
git push
