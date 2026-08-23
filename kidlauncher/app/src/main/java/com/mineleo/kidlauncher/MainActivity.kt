package com.mineleo.kidlauncher

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import android.widget.Toast

private const val MINECRAFT_PACKAGE = "com.mojang.minecraftpe"

/**
 * Tela única: se o app é dono do dispositivo (dpm set-device-owner), habilita
 * o modo Lock Task para si mesmo e para o Minecraft, e então abre o Minecraft.
 * Sem provisionamento de device-owner, apenas abre o Minecraft normalmente
 * (o usuário pode ativar manualmente o "Pin de app" do Android para travar).
 */
class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, KioskDeviceAdminReceiver::class.java)
        val isOwner = dpm.isDeviceOwnerApp(packageName)

        if (isOwner) {
            dpm.setLockTaskPackages(admin, arrayOf(packageName, MINECRAFT_PACKAGE))
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(MINECRAFT_PACKAGE)
        if (launchIntent == null) {
            setContentView(TextView(this).apply {
                text = "Minecraft não está instalado neste aparelho."
                textSize = 20f
                setPadding(48, 96, 48, 48)
            })
            Toast.makeText(this, "Instale o Minecraft (Bedrock) primeiro.", Toast.LENGTH_LONG).show()
            return
        }

        if (isOwner) {
            startLockTask()
        }
        startActivity(launchIntent)

        if (!isOwner) {
            // Sem device-owner, quem trava a tela é o próprio usuário via
            // Configurações > Segurança > Fixar app, escolhendo o Minecraft.
            finish()
        }
    }
}
