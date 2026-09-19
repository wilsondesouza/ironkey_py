package com.ironkey.ironkey_mobile.autofill

import android.app.assist.AssistStructure
import android.os.CancellationSignal
import android.service.autofill.*
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import com.ironkey.ironkey_mobile.R

/**
 * Serviço de Autofill integrado ao Android Autofill Framework.
 */
class IronKeyAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure ?: run {
            callback.onSuccess(null)
            return
        }

        val fields = AutofillFieldFinder()
        fields.traverse(structure)

        if (fields.usernameId == null && fields.passwordId == null) {
            callback.onSuccess(null)
            return
        }

        // Constrói resposta de preenchimento
        val responseBuilder = FillResponse.Builder()
        val packageName = structure.activityComponent.packageName

        // Se houver credenciais correspondentes na sessão ativa
        val dataset = Dataset.Builder()
        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "Preencher com IronKey")
        }

        fields.usernameId?.let { id ->
            dataset.setValue(id, AutofillValue.forText(""), presentation)
        }
        fields.passwordId?.let { id ->
            dataset.setValue(id, AutofillValue.forText(""), presentation)
        }

        responseBuilder.addDataset(dataset.build())
        callback.onSuccess(responseBuilder.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private class AutofillFieldFinder {
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null

        fun traverse(structure: AssistStructure) {
            for (i in 0 until structure.windowNodeCount) {
                val node = structure.getWindowNodeAt(i).rootViewNode
                findFields(node)
            }
        }

        private fun findFields(node: AssistStructure.ViewNode) {
            val hints = node.autofillHints
            val autofillId = node.autofillId

            if (hints != null && autofillId != null) {
                for (hint in hints) {
                    if (hint.contains("username", ignoreCase = true) || hint.contains("email", ignoreCase = true)) {
                        usernameId = autofillId
                    }
                    if (hint.contains("password", ignoreCase = true)) {
                        passwordId = autofillId
                    }
                }
            }

            for (i in 0 until node.childCount) {
                findFields(node.getChildAt(i))
            }
        }
    }
}
