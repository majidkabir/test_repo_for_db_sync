SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580RcvFilter12                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Defy                                                        */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2024-08-21   1.0  JHU151     FCR-550. Created                        */  
/************************************************************************/

CREATE   PROC [RDT].[rdt_1580RcvFilter12]
    @nMobile     INT              
   ,@nFunc       INT              
   ,@cLangCode   NVARCHAR(  3)   
   ,@cReceiptKey NVARCHAR( 10)   
   ,@cPOKey      NVARCHAR( 10)   
   ,@cToLOC      NVARCHAR( 10)   
   ,@cToID       NVARCHAR( 18)   
   ,@cSKU        NVARCHAR( 20)   
   ,@cUCC        NVARCHAR( 20)   
   ,@nQTY        INT             
   ,@cLottable01 NVARCHAR( 18)   
   ,@cLottable02 NVARCHAR( 18)   
   ,@cLottable03 NVARCHAR( 18)   
   ,@dLottable04 DATETIME         
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT 
   ,@nErrNo      INT            OUTPUT 
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSerialNo NVARCHAR(40)
   DECLARE @cAddRCPTValidtn     NVARCHAR(10),
           @cStorerKey          NVARCHAR(20)
   
   SELECT @cSerialNo = V_Max,
		  @cStorerKey = StorerKey
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

   SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddRCPTValidtn', @cStorerKey)
   
   IF @cAddRCPTValidtn = '1'
   BEGIN
      

      SET @cCustomSQL = @cCustomSQL + 
         '     AND UserDefine01 = ''' + @cSerialNo + ''''
   END  

QUIT:
END -- End Procedure

GO