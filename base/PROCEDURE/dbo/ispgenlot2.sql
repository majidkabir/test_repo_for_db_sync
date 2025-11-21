SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispGenLot2                                          */  
/* Copyright: IDS                                                       */  
/* Purpose: Update Lottable02 with ReceiptKey_ReceiptLine               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2014-07-22   James     1.0   SOS315958 Create                        */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispGenLot2]  
   @cReceiptKey  NVARCHAR(10),  
   @bSuccess     INT = 1  OUTPUT,  
   @nErrNo       INT = 0  OUTPUT,  
   @cErrMsg      NVARCHAR(250) = '' OUTPUT,  
   @c_ReceiptLineNumber  NVARCHAR(5) = ''   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cStorerKey    NVARCHAR( 15),  
           @cUDStorerKey  NVARCHAR( 15)  
     
   SET @bSuccess = 1  
     
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT ReceiptLineNumber FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   ORDER BY ReceiptLineNumber
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
         Lottable02 = @cReceiptKey + '_' + @c_ReceiptLineNumber
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @c_ReceiptLineNumber

      FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
QUIT:  
  
END -- End Procedure  

GO