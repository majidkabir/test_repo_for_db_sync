SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839ExtUpd02                                           */
/* Purpose: TM Replen From, Extended Update for KR                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-09-02   Chermaine 1.0   WMS-17827 Created                             */
/* 2022-04-20   YeeKung   1.1   WMS-19311 Add Data capture (yeekung02)        */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtUpd02]
    @nMobile         INT                   
   ,@nFunc           INT                    
   ,@cLangCode       NVARCHAR( 3)           
   ,@nStep           INT                    
   ,@nInputKey       INT                    
   ,@cFacility       NVARCHAR( 5)           
   ,@cStorerKey      NVARCHAR( 15)          
   ,@cPickSlipNo     NVARCHAR( 10)          
   ,@cPickZone       NVARCHAR( 10)          
   ,@cDropID         NVARCHAR( 20)          
   ,@cLOC            NVARCHAR( 10)          
   ,@cSKU            NVARCHAR( 20)          
   ,@nQTY            INT                    
   ,@cOption         NVARCHAR( 1)           
   ,@cLottableCode   NVARCHAR( 30)          
   ,@cLottable01     NVARCHAR( 18)          
   ,@cLottable02     NVARCHAR( 18)          
   ,@cLottable03     NVARCHAR( 18)          
   ,@dLottable04     DATETIME               
   ,@dLottable05     DATETIME               
   ,@cLottable06     NVARCHAR( 30)          
   ,@cLottable07     NVARCHAR( 30)          
   ,@cLottable08     NVARCHAR( 30)          
   ,@cLottable09     NVARCHAR( 30)          
   ,@cLottable10     NVARCHAR( 30)          
   ,@cLottable11     NVARCHAR( 30)          
   ,@cLottable12     NVARCHAR( 30)          
   ,@dLottable13     DATETIME               
   ,@dLottable14     DATETIME               
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR(250) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT   
   DECLARE @nExists  INT
   DECLARE @cShort   NVARCHAR(20)
   DECLARE @cWCS     NVARCHAR(1)
   
   -- TM Replen From
   IF @nFunc = 839
   BEGIN      
      IF @nStep IN (3,5) -- sku screen , Confirm option screen
      BEGIN
         IF @nInputKey = 1 
         BEGIN
            -- Get storer config    
            EXEC nspGetRight  
               @c_Facility   = @cFacility    
            ,  @c_StorerKey  = @cStorerKey   
            ,  @c_sku        = ''         
            ,  @c_ConfigKey  = 'WCS'   
            ,  @b_Success    = @bSuccess  OUTPUT  
            ,  @c_authority  = @cWCS      OUTPUT   
            ,  @n_err        = @nErrNo    OUTPUT  
            ,  @c_errmsg     = @cErrMsg   OUTPUT
      
            SELECT 
               @nExists = 1 
            FROM codelkup WITH (NOLOCK) 
            WHERE storerKey = @cStorerKey 
            AND listName = 'WSWCSITF'
            AND code = @nFunc
           
            IF (@cWCS = '1') AND  @nExists = 1 
            BEGIN
            	IF NOT EXISTS (SELECT 1 FROM dbo.TRANSMITLOG2 WITH (NOLOCK) WHERE key1 = @cPickSlipNo AND Key2 = @cDropID)
            	BEGIN
                  SELECT 
                     @cShort = short 
                  FROM codelkup WITH (NOLOCK) 
                  WHERE storerKey = @cStorerKey 
                  AND listName = 'WSWCSITF'
                  AND code = @nFunc
            
      	         EXEC dbo.ispGenTransmitLog2  
                     @c_TableName      = @cShort,  
                     @c_Key1           = @cPickSlipNo,  
                     @c_Key2           = @cDropID ,  
                     @c_Key3           = @cStorerKey,  
                     @c_TransmitBatch  = '',  
                     @b_success        = @bSuccess    OUTPUT,  
                     @n_err            = @nErrNo      OUTPUT,  
                     @c_errmsg         = @cErrMsg     OUTPUT  
  
                  IF @bSuccess <> 1  
                  BEGIN  
                     SET @nErrNo = 175301  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog2 Fail'  
                     GOTO Quit  
                  End  
               END
            END
         END
      END
   END

Quit:


END

GO