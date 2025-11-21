SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832Confirm01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: full carton pack                                            */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2020-07-14  1.0  Ung       WMS-13699 Created (based on std Confirm)  */
/* 2023-01-30  1.1  Ung       WMS-21570 Add @cPrintPackList param       */ 
/************************************************************************/

CREATE   PROC [RDT].[rdt_832Confirm01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cType            NVARCHAR( 10), --CHECK/CONFIRM
   @tConfirm         VariableTable READONLY, 
   @cDoc1Value       NVARCHAR( 20),
   @cCartonID        NVARCHAR( 20),
   @cCartonSKU       NVARCHAR( 20),
   @nCartonQTY       INT, 
   @cPackInfo        NVARCHAR( 4)  = '', 
   @cCartonType      NVARCHAR( 10) = '',
   @fCube            FLOAT         = 0,
   @fWeight          FLOAT         = 0,
   @cPackInfoRefNo   NVARCHAR( 20) = '',
   @cPickSlipNo      NVARCHAR( 10) OUTPUT,
   @nCartonNo        INT           OUTPUT,
   @cLabelNo         NVARCHAR( 20) OUTPUT,
   @cPrintPackList   NVARCHAR( 1)  OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*
      This is to merge 2 different pack carton ID processes, all into FN832, and to retire FN834:
         a. CartonID = PickDetail.DropID (previously run under FN834)
         b. CartonID = UPC (already run under FN832)

                              FN834 (DropID)       FN832 (SKU)          FN832 (to be)
      DecodeSP                                     1                    Done. Set = rdt_832Decode01 (31 chars = SKU so abstract UPC, otherwise treat as DropID)
      ExtendedPackCfmSP       rdt_834ExtPack02     rdt_832ExtPack01     Done. Set = rdt_832Confirm01 (internally call sub SP for DropID and SKU)
      ExtendedValidateSP      rdt_834ExtValid02                         Done. Set = blank (rdt_834ExtValid02 merge into sub SP for DropID)
      GenLabelNo_SP                                isp_GLBL09           Done. No change (hardcode in sub sp of DropID)
      PackByPickDetailDropID  1                                         Done. No change (both sub SP does not have PackByPickDetailDropID)
      PackDetailCartonID                           UPC                  Done. No change (sub sp of DropID does not have PackDetailCartonID)
      PackList                PACKLIST02           PACKLIST02           Done. No change
      ShipLabel               UCCLbConSO           UCCLbConSO           Done. No change (remove ship label in sub SP for DropID)
      UpdatePickDetail        1                    1                    Done. No change
   */

   IF EXISTS( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonID)
   BEGIN
      -- By DropID
      EXEC rdt.rdt_832Confirm01_DropID
          @nMobile        = @nMobile        
         ,@nFunc          = @nFunc          
         ,@cLangCode      = @cLangCode      
         ,@nStep          = @nStep          
         ,@nInputKey      = @nInputKey      
         ,@cStorerKey     = @cStorerKey     
         ,@cFacility      = @cFacility      
         ,@cType          = @cType          
         ,@tConfirm       = @tConfirm
         ,@cDoc1Value     = @cDoc1Value     
         ,@cCartonID      = @cCartonID      
         ,@cCartonSKU     = @cCartonSKU     
         ,@nCartonQTY     = @nCartonQTY     
         ,@cPackInfo      = @cPackInfo      
         ,@cCartonType    = @cCartonType    
         ,@fCube          = @fCube          
         ,@fWeight        = @fWeight        
         ,@cPackInfoRefNo = @cPackInfoRefNo    
         ,@cPickSlipNo    = @cPickSlipNo    OUTPUT
         ,@nCartonNo      = @nCartonNo      OUTPUT
         ,@cLabelNo       = @cLabelNo       OUTPUT
         ,@nErrNo         = @nErrNo         OUTPUT
         ,@cErrMsg        = @cErrMsg        OUTPUT
   END
   ELSE
   BEGIN
      -- By SKU
      EXEC rdt.rdt_832Confirm01_SKU
          @nMobile        = @nMobile        
         ,@nFunc          = @nFunc          
         ,@cLangCode      = @cLangCode      
         ,@nStep          = @nStep          
         ,@nInputKey      = @nInputKey      
         ,@cStorerKey     = @cStorerKey     
         ,@cFacility      = @cFacility      
         ,@cType          = @cType          
         ,@tConfirm       = @tConfirm
         ,@cDoc1Value     = @cDoc1Value     
         ,@cCartonID      = @cCartonID      
         ,@cCartonSKU     = @cCartonSKU     
         ,@nCartonQTY     = @nCartonQTY     
         ,@cPackInfo      = @cPackInfo      
         ,@cCartonType    = @cCartonType    
         ,@fCube          = @fCube          
         ,@fWeight        = @fWeight        
         ,@cPackInfoRefNo = @cPackInfoRefNo    
         ,@cPickSlipNo    = @cPickSlipNo    OUTPUT
         ,@nCartonNo      = @nCartonNo      OUTPUT
         ,@cLabelNo       = @cLabelNo       OUTPUT
         ,@nErrNo         = @nErrNo         OUTPUT
         ,@cErrMsg        = @cErrMsg        OUTPUT
   END

Quit:

END

GO