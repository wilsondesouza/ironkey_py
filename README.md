# IronKey Mobile 📱

Aplicativo móvel do **IronKey** desenvolvido em **Flutter** com módulo nativo em **Kotlin** de alta segurança, compatível com o ecossistema e o contrato de sincronização do desktop (**v2.1.0+**).

---

## 🏗️ Arquitetura

O aplicativo segue uma arquitetura híbrida estratégica projetada para segurança e privacidade:

```
┌────────────────────────────────────────────────────────┐
│                   Flutter UI (Dart)                    │
│   Telas: Cofre, Gerador, Detalhes, Conflitos, Ajustes  │
│   State Management (VaultProvider) & Cache Local       │
└──────────────────────────┬─────────────────────────────┘
                           │ (MethodChannel)
┌──────────────────────────▼─────────────────────────────┐
│                 Módulo Nativo (Kotlin)                 │
│  • Criptografia: Argon2id (BouncyCastle) + AES-256-GCM │
│  • Storage Access Framework (SAF): Persistência Nuvem  │
│  • Android Keystore: Proteção de Chaves e Biometria    │
│  • Android Autofill Service: Preenchimento Automático  │
└────────────────────────────────────────────────────────┘
```

---

## 🔑 Segurança e Criptografia

- **Argon2id Nativo:** Derivação da KEK em código nativo de alta performance (sem vazamento de memória para o garbage collector do Dart).
- **AES-256-GCM:** Cifragem de cada registro com Associated Authenticated Data (AAD) garantindo integridade contra adulteração.
- **Storage Access Framework (SAF):** O app não solicita permissões invasivas de armazenamento (`MANAGE_EXTERNAL_STORAGE`). O usuário escolhe a pasta em nuvem (Google Drive, Dropbox, Nextcloud, Syncthing) com permissão persistente (`takePersistableUriPermission`).
- **Autofill Service:** Integrado diretamente ao framework nativo do Android (`android.service.autofill.AutofillService`), preenchendo credenciais em navegadores e apps com proteção de domínio.
- **Área de Transferência Segura:** Limpeza automática de senhas copiadas após 30 segundos.
- **Bloqueio Automático:** Trancamento do cofre ao colocar o app em segundo plano ou após inatividade.

---

## 🚀 Como Executar no Android

### Pré-requisitos
- Flutter SDK (>= 3.0.0)
- Android SDK (API 36+)
- Dispositivo Android ou Emulador

### Passos
1. Entre na pasta mobile:
   ```bash
   cd mobile
   ```
2. Obtenha as dependências:
   ```bash
   flutter pub get
   ```
3. Execute no emulador ou dispositivo conectado:
   ```bash
   flutter run
   ```

---

## 🔄 Como Parear com o Desktop

1. No **Desktop**, vá em **Configurações** ➔ aba **Sincronização** ➔ clique em **"Exportar entrada para 2º dispositivo"**.
2. Salve o arquivo `.ikenr` e transfira para o celular (ex: via cabo, compartilhamento local seguro).
3. No **Mobile**, na tela inicial, toque em **"Importar Entrada de Dispositivo (.ikenr)"**.
4. Cole o conteúdo do arquivo e digite a sua Senha Mestre.
5. Nas **Configurações** do Mobile, selecione a mesma pasta de sincronização do seu cliente de nuvem (SAF).
6. O cofre do celular sincronizará automaticamente com o desktop!
