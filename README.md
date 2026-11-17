# ajukas.pritunl

Widget da barra do Omarchy para a VPN do Pritunl, usando o `pritunl-client` (pacote AUR
`pritunl-client-bin`, que não tem interface gráfica).

- Clique esquerdo: abre o card com o status, o campo de PIN e o botão Conectar/Desconectar.
  Digite o PIN e aperte Enter para conectar.
- Clique direito: desconecta.
- O ícone acende enquanto a VPN está conectada; o tooltip mostra o IP recebido.

O status vem de `pritunl-client list -j`, consultado a cada 5 s (1 s enquanto conecta).
Por padrão usa o primeiro perfil importado; para escolher outro, defina `profileId`
nas configurações do widget.

## Instalação

```sh
ln -s ~/project/plugins/ajukas.pritunl ~/.config/omarchy/plugins/ajukas.pritunl
omarchy-shell shell rescanPlugins
omarchy plugin enable ajukas.pritunl
```

Como o plugin é um link simbólico, edições aqui não recarregam sozinhas; rode
`omarchy restart shell` depois de alterar o código.
