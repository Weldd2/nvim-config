return {
  -- Parser treesitter pour la coloration des blocs <style> dans les .vue.
  -- L'extra Vue installe déjà `vue` + `css` ; on ajoute scss pour que
  -- <style lang="scss"> soit correctement surligné (injection treesitter).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "scss" } },
  },

  -- Active le "rich hover" de vue-language-tools v3 : affiche le type / les
  -- infos d'un composant quand on survole son tag dans le <template>
  -- (ex. <KiiwiButton>). Feature expérimentale, OFF par défaut.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vue_ls = {
          settings = {
            vue = {
              hover = {
                rich = true,
              },
            },
          },
        },
      },
    },
  },
}
