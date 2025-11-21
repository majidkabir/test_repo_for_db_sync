SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  rdt_LottableProcess_ValidL4L12                             */
/* Creation Date: 27-Dec-2010                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 07-Jun-2024  SHONG     1.0   Created                                 */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_ValidL4L12]
   @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE
        @dt_ExpirationDate         DATETIME,
        @cDamagedCode            NVARCHAR(30),
        @cExpiredCode            NVARCHAR(30)

   IF ISNULL(@cLottable12Value,'') <> ''
   BEGIN

      IF EXISTS (   SELECT 1
                  FROM CODELKUP WITH (NOLOCK) 
                  WHERE LISTNAME = 'ASNREASON'
                     AND Code = @cLottable12Value
                     AND StorerKey = @cStorerkey)
      BEGIN
         SET @cDamagedCode = ''

         SELECT @cDamagedCode = ISNULL(Code,'')
         FROM CODELKUP WITH (NOLOCK)
         WHERE storerkey = @cStorerkey
         AND UDF01 = 'RMPM_Damaged'
         AND LISTNAME = 'SLCode'

         IF ISNULL(@cDamagedCode,'') <> ''
         BEGIN
               SET @cLottable06 = '1'
               SET @cLottable07 = @cDamagedCode
         END
         ELSE 
         BEGIN
            SET @nErrNo = 63533;
            SET @cErrMsg = 'Damaged Code is not configured for this Storer key' +@cStorerkey;
            GOTO QUIT
         END 
      END 
   END 

   IF ISNULL(@dLottable04Value,'') <> ''
   BEGIN
      IF DATEDIFF(DAY, GETDATE(), @dLottable04Value) <= 0
      BEGIN
         SET @cExpiredCode = ''

         SELECT @cExpiredCode = ISNULL(Code,'')
         FROM CODELKUP WITH (NOLOCK)
         WHERE storerkey = @cStorerkey
            AND UDF01 = 'RMPM_Expired' 
            AND LISTNAME = 'SLCode'         
               
         IF ISNULL(@cExpiredCode,'') = ''
         BEGIN
            SET @nErrNo = 63533;
            SET @cErrMsg = 'Expired Code is not configured for this Storer key' +@cStorerkey;
            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @cLottable07 = @cExpiredCode
            SET @cLottable06 = '1'
         END
      END
   END

QUIT:

END -- End Procedure


GO