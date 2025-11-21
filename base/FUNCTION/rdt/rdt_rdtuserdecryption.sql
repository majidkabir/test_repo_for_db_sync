SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Function: rdt_RDTUserDecryption                               */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: UWP- 21905                                                 */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Version    Author   Purposes                            */
/* 2024-07-26   1.0        JACKC    UWP-21905 created                   */
/************************************************************************/
CREATE FUNCTION rdt.rdt_RDTUserDecryption
(
   @cUsrName            NVARCHAR(18),
   @cEncryptPassword    NVARCHAR(32)
)
RETURNS NVARCHAR(15)
BEGIN

   DECLARE
      @cPassword NVARCHAR(15) 
   
   SET @cPassword = MASTER.dbo.fnc_CryptoDecrypt(@cEncryptPassword, UPPER(@cUsrName))

   RETURN @cPassword
END

GO