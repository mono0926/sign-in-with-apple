import * as admin from 'firebase-admin'
import * as functions from 'firebase-functions'
import * as util from 'util'

admin.initializeApp()

const logger = functions.logger

export const siwa = functions.https.onRequest((request, response) => {
  logger.log(`siwa request: ${util.inspect(request)}`)

  const redirect = `intent://callback?${new URLSearchParams(
    request.body
  ).toString()}#Intent;package=${
    'com.mono0926.siwa' // applicationId of app/build.gradle
  };scheme=signinwithapple;end`

  logger.log(`Redirecting to ${redirect}`)

  response.redirect(307, redirect)
})

