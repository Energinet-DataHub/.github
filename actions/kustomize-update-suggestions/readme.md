# Good to know

When moved from the `acorn-actions`-repository to this repository, the action did not work as intended because the **executable permission** (`chmod +x`) wasn't preserved.

To fix this issue, write the following in a bash terminal:

``` bash
git update-index --chmod=+x ./actions/kustomize-update-suggestions/update-helm.sh
git update-index --chmod=+x ./actions/kustomize-update-suggestions/update-images.sh
git commit -m "make sh scripts executable"
git push
```
