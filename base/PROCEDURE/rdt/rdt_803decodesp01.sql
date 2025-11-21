SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 /************************************************************************/  
/* Store procedure: rdt.rdt_803DecodeSP01                                  */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 24-03-2022  1.1  yeekung     WMS-18729 Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_803DecodeSP01]    (
      @nMobile      INT           
    , @nFunc        INT           
    , @cLangCode    NVARCHAR( 3)  
    , @nStep        INT           
    , @nInputKey    INT           
    , @cFacility    NVARCHAR( 5)  
    , @cStorerKey   NVARCHAR( 15) 
    , @cStation     NVARCHAR( 10) 
    , @cMethod      NVARCHAR( 10) 
    , @cBarcode     NVARCHAR( 60) 
    , @cUPC         NVARCHAR( 30)   OutPut  
    , @nErrNo       INT             OutPut
    , @cErrMsg      NVARCHAR( 20)   OutPut
)
As
Begin
    If @nStep = 3
    Begin
        Declare @Sku NVARCHAR( 30),
                @cLoadkey NVARCHAR(20)

        Select @cLoadkey=Loadkey 
        From rdt.rdtPTLPieceLog 
        Where Station = @cStation 

        Select Top 1 @Sku = SKU.Sku  
        From PickDetail PD (NoLock) 
        Join Sku SKU (NoLock) On PD.Storerkey = SKU.Storerkey And PD.Sku = SKU.Sku
        JOIN Orders O (NOLOCK) ON PD.orderkey=O.orderkey
        Where o.loadkey=@cLoadkey
            And ( SKU.Sku = @cUPC Or SKU.AltSku = @cUPC OR SKU.Sku= @cUPC or SKU.RetailSKU=@cUPC or SKU.Manufacturersku=@cUPC) 
            And PD.CaseID <> 'SORTED'
    
        If Isnull(@Sku , '') <> ''
        Begin
           Set @cUPC = @Sku
        End
    End
End

GO