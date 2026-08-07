MODDIR=${0%/*}
cd "${MODDIR}"
shfmt_dir="${MODDIR}/shfmt"
chmod -R 7777 ${MODDIR}
chmod +x "${shfmt_dir}"
"${shfmt_dir}" -w .
echo 'done.'
