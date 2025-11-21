SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/    
/* Store procedure: rdt_832ExtUpd01                                     */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 06-01-2023  1.0  Ung         WMS-21489 Created                       */    
/* 03-02-2023  1.1  KY01        Fix Bug                                 */    
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_832ExtUpd01] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,    
   @nInputKey      INT,    
   @cStorerKey     NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @tExtUpd        VariableTable READONLY,    
   @cDoc1Value     NVARCHAR( 20),    
   @cCartonID      NVARCHAR( 20),    
   @cSKU           NVARCHAR( 20),    
   @nQTY           INT,    
   @cPackInfo      NVARCHAR( 4),    
   @cCartonType    NVARCHAR( 10),    
   @cCube          NVARCHAR( 10),    
   @cWeight        NVARCHAR( 10),    
   @cPackInfoRefNo NVARCHAR( 20),     
   @cPickSlipNo    NVARCHAR( 10),    
   @nCartonNo      INT,    
   @cLabelNo       NVARCHAR( 20),    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   IF @nFunc = 832 -- carton pack    
   BEGIN    
      IF @nStep = 2 OR -- Carton ID    
         @nStep = 4    -- Pack info    
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN    
            DECLARE @bSuccess INT    
            EXEC dbo.ispGenTransmitLog2    
                 'WSPCKRFIDLOG'  -- TableName    
               , @cPickSlipNo    -- Key1    
               , @cLabelNo       -- Key2    
               , @cStorerKey     -- Key3    
               , ''              -- Batch    
               , @bSuccess  OUTPUT    
               , @nErrNo    OUTPUT    
               , @cErrMsg   OUTPUT    
            IF @bSuccess <> 1    
            BEGIN    
               SET @nErrNo = 144251    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG2 Fail    
               GOTO Quit    
            END    
                
            DECLARE @cTransmitLogKey NVARCHAR( 10) = ''    
            SELECT @cTransmitLogKey = TransmitLogKey    
            FROM dbo.TransmitLog2 WITH (NOLOCK)    
            WHERE TableName = 'WSPCKRFIDLOG'    --KY01   
               AND Key1 = @cPickSlipNo    
               AND Key2 = @cLabelNo    
               AND Key3 = @cStorerKey    
              
            IF ISNULL(@cTransmitLogKey, '') <> ''    --KY01  
            BEGIN                                    --KY01  
               EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert       
                  @c_QCmdClass         = '', --@c_QCmdClass       
                  @c_FrmTransmitlogKey = @cTransmitLogKey,       
                  @c_ToTransmitlogKey  = @cTransmitLogKey,       
                  @b_Debug             = 0,  --@b_Debug     
                  @b_Success           = @bSuccess    OUTPUT,       
                  @n_Err               = @nErrNo      OUTPUT,       
                  @c_ErrMsg            = @cErrMsg     OUTPUT       
               IF @bSuccess <> 1    
               BEGIN    
                  SET @nErrNo = 144252    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Send QCmd Fail    
                  GOTO Quit    
               END    
            END   --KY01  
         END    
      END    
   END    
    
Quit:    
    
END 

GO