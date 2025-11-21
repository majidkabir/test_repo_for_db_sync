SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispUpdateDXRcptCfm : 
--

/************************************************************************/
/* Store Procedure:  ispUpdateDXRcptCfm                                 */
/* Creation Date: 14-Oct-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: Ong GB                                                   */
/*                                                                      */
/* Purpose:  Retry 3 times for TransmitLog Updating if table was locked */
/*                                                                      */
/* Usage:  Used for DX Interface                                        */
/*                                                                      */
/* Called By: DX GoodsReceiptExport.bas                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispUpdateDXRcptCfm] (
 @cReceiptKey        NVARCHAR(10),
 @cReceiptLineNumber NVARCHAR(5),
 @bSuccess           int OUTPUT, 
 @nErrNo             int OUTPUT, 
 @cErrMsg            NVARCHAR(215) OUTPUT  
) 
AS
BEGIN
   DECLARE @nRetry int, 
           @cTransmitLogKey NVARCHAR(10) 
   
   SET @cTransmitLogKey = ''

   SELECT @cTransmitLogKey = TransmitlogKey
   FROM   TransmitLog (NOLOCK)
   Where TableName = 'OWRCPT'
   And    Transmitflag = '1'
   And   Key1 = @cReceiptKey
   And   Key2 = @cReceiptLineNumber

   SET LOCK_TIMEOUT 18000 

   IF ISNULL(dbo.fnc_RTRIM(@cTransmitLogKey), '') <> '' 
   BEGIN 
      SET @bSuccess = 1
      WHILE @bSuccess = 1   
      BEGIN 
         SET @nRetry = 0
   
         WHILE @nRetry < 3 
         BEGIN   
            Update Transmitlog WITH (ROWLOCK) 
            Set   Transmitflag = '9' 
            WHERE TransmitLogKey = @cTransmitLogKey 
   
            IF @@ERROR = 1222 -- Timeout for locking 
            BEGIN
               WAITFOR DELAY '00:00:05'
               SET @nRetry = @nRetry + 1 
   
               IF @nRetry >= 3 
               BEGIN
                  SET @bSuccess = 0 
                  SET @nErrNo  = @@ERROR 
                  SET @cErrMsg = 'Timeout! (ispUpdateDXRcptCfm)'
               END 
            END
            ELSE IF @@ERROR <> 0 -- Error not cause by Locking 
            BEGIN
               SET @bSuccess = 0 
               SET @nErrNo  = @@ERROR 
               SET @cErrMsg = 'Update TransmitLog Failed! (ispUpdateDXRcptCfm)'
               BREAK 
            END 
            ELSE
            BEGIN
               SET @bSuccess = 1
               BREAK
            END 
            
         END 
      END -- Cursor Loop 
   END -- ISNULL(dbo.fnc_RTRIM(@cTransmitLogKey), '') <> ''

END -- Procedure

GO