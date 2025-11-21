SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: rdt_958ExtUpd01                                     */              
/*                                                                      */              
/* Purpose: Get suggested loc                                           */              
/*                                                                      */              
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */              
/*                                                                      */              
/* Date         Rev  Author   Purposes                                  */              
/* 21-09-2022   1.0  yeekung  WMS-22940. Created                        */        
/************************************************************************/              
              
CREATE   PROC [RDT].[rdt_958ExtUpd01] (              
   @nMobile          INT,               
   @nFunc            INT,               
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT,
   @nInputKey        INT,                     
   @cFacility        NVARCHAR( 5)   ,
   @cStorerKey       NVARCHAR( 15)  ,
   @cPickSlipNo      NVARCHAR( 20)  ,
   @cSuggestedLOC    NVARCHAR( 10)  ,
   @cSuggSKU         NVARCHAR( 20)  ,
   @nQTY             INT            ,
   @cUCCNo           NVARCHAR( 20)  ,
   @cDropID          NVARCHAR( 20)  ,
   @cOption          NVARCHAR( 1)   ,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT         
) AS              
BEGIN              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF     
   
   DECLARE @cTableName  NVARCHAR(20)
   DECLARE @nCartonNo   NVARCHAR(5)
   DECLARE @bSuccess    INT
   DECLARE @cTransmitLogKey NVARCHAR(20)
   DECLARE @b_Debug NVARCHAR(20)
   DECLARE @cItemClass NVARCHAR(20)
   DECLARE @cOrderKey   NVARCHAR(20)

   IF @nStep='5'
   BEGIN
      IF @nInputKey='1'
      BEGIN

         DECLARE @nWeight        FLOAT = 0
         DECLARE @nCube          FLOAT
         DECLARE @cCartonType    NVARCHAR( 10)
         DECLARE @nCartonWeight  FLOAT =0
         DECLARE @nCartonCube    FLOAT =0
         DECLARE @nCartonLength  FLOAT =0
         DECLARE @nCartonWidth   FLOAT =0
         DECLARE @nCartonHeight  FLOAT =0

         IF  ISNULL(@cSuggSKU,'')=''
            SELECT @cSuggSKU =sku
            FROM UCC (NOLOCK)
            WHERE UCCNo=@cUCCNo
            AND storerkey=@cStorerKey

         SELECT @cItemClass =itemclass
         FROM SKU (NOLOCK)
         WHERE SKU=@cSuggSKU
         AND storerkey=@cStorerKey

         SELECT TOP 1
            @cCartonType = CartonType,
            @nCartonWeight = ISNULL( CartonWeight, 0),
            @nCartonCube = ISNULL( Cube, 0),
            @nCartonLength = ISNULL( CartonLength, 0),
            @nCartonWidth  = ISNULL( CartonWidth, 0),
            @nCartonHeight = ISNULL( CartonHeight, 0)
         FROM Storer S WITH (NOLOCK)
            JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
         WHERE S.StorerKey = @cStorerKey
         and cartontype = @cItemClass

         
         IF ISNULL(@cCartonType,'')=''
         BEGIN
           SELECT TOP 1
               @cCartonType = CartonType,
               @nCartonWeight = ISNULL( CartonWeight, 0),
               @nCartonCube = ISNULL( Cube, 0),
               @nCartonLength = ISNULL( CartonLength, 0),
               @nCartonWidth  = ISNULL( CartonWidth, 0),
               @nCartonHeight = ISNULL( CartonHeight, 0)
            FROM Storer S WITH (NOLOCK)
               JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
            WHERE S.StorerKey = @cStorerKey
            and cartontype = 'CTN'
         END

         SELECT TOP 1 @nCartonNo=cartonno
         FROM PACKDETAIL (NOLOCK)
         WHERE pickslipno=@cPickSlipNo
         AND sku=@cSuggSKU
         AND storerkey=@cStorerKey
         ORDER by AddDate desc;

         IF NOT EXISTS (SELECT 1 FROM PACKINFO   (NOLOCK)
                    WHERE pickslipno=@cPickSlipNo
                    AND cartonno=@nCartonNo)
         BEGIN
            SET  @nWeight = @nCartonWeight
            -- Insert PackInfo
            INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty, Cartontype, Length, Width, Height)
            VALUES (@cPickSlipNo, @nCartonNo, @nCartonWeight, @nCartonCube, @nQTY, @cCartonType, @nCartonLength, @nCartonWidth, @nCartonHeight)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 191101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS PKInf Fail
               GOTO QUIT
            END

         END
         ELSE
         BEGIN
            UPDATE PackInfo WITH (ROWLOCK)
            SET Qty=Qty+@nQTY,
                weight = @nCartonWeight
            WHERE pickslipno=@cPickSlipNo
               AND cartonno=@nCartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 192102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD PKInf Fail
               GOTO QUIT
            END
         END 

         SELECT @cOrderKey = Orderkey
         FROM PACKHEADER (NOLOCK)
         WHERE pickslipno=@cPickSlipNo
            AND Storerkey = @cStorerKey
         
         EXEC [dbo].[isp_Carrier_Middleware_Interface]          
         @c_OrderKey    = @cOrderKey       
         , @c_Mbolkey     = ''    
         , @c_FunctionID  = @nFunc        
         , @n_CartonNo    = @nCartonNo    
         , @n_Step        = @nStep    
         , @b_Success     = @bSuccess  OUTPUT          
         , @n_Err         = @nErrNo    OUTPUT          
         , @c_ErrMsg      = @cErrMsg   OUTPUT     

      END
   END
              
    
Quit:              
END 

GO