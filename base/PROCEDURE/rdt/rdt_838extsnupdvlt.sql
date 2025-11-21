SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/  
/* Store procedure: rdt_838ExtSNUpdVLT                                        */    
/* Copyright      : Maersk                                                    */
/*                                                                            */  
/* Date        Rev   Author   Purposes                                        */  
/* 22/05/2024  1.0.0 PPA374   Insert SN data in the Serial Number table       */  
/* 08/08/2024  1.1.0 PPA374   Amended as per review comments                  */
/* 2024-12-04  1.2.0 PXL009   FCR-778 Violet Pack Changes                     */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_838ExtSNUpdVLT]  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cSerialNo    NVARCHAR( 30),
   @cType        NVARCHAR( 15), --CHECK/INSERT
   @cDocType     NVARCHAR( 10),
   @cDocNo       NVARCHAR( 20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount  INT  
   DECLARE @cChkStatus NVARCHAR(10)  
   DECLARE @cChkExternStatus NVARCHAR(10)  
   DECLARE 
      @cSerialNoKey NVARCHAR(20),
      @cOrderLineNumber NVARCHAR(5),
      @bsuccess INT =0,
      @cOrderkey NVARCHAR(20)
  
   IF @nFunc = 838 AND @nStep = 9 AND @nInputKey = 1 --Pack, Serial number screen
   BEGIN
      SELECT TOP 1 @cOrderkey = PD.Orderkey 
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.PICKHEADER PH (NOLOCK)
      ON PH.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey  
         AND PH.PickHeaderKey = @cDocNo  
         AND PD.SKU = @cSKU  

      IF EXISTS (SELECT 1 FROM dbo.SerialNo (NOLOCK) WHERE StorerKey = @cStorerKey AND SerialNo = @cSerialNo AND (OrderKey <> @cOrderkey OR SKU <> @cSKU))
      BEGIN
         SET @nErrNo = 230001
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'SN is already used' 
         GOTO quit
      END
      
      -- Get serial no info  
      SELECT TOP 1  
      @cChkStatus = Status,   
      @cChkExternStatus = ExternStatus  
      FROM dbo.SerialNo WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND OrderKey = @cOrderkey
         AND SKU = @cSKU  
         AND SerialNo = @cSerialNo
      SET @nRowCount = @@ROWCOUNT  
  
      -- Check SNO in ASN  
      IF @nRowCount = 0  
      BEGIN  
         
         EXECUTE dbo.nspg_GetKey  
         'SerialNo',  
         10 ,  
         @cSerialNoKey      OUTPUT,  
         @bsuccess          OUTPUT,  
         @nErrNo            OUTPUT,  
         @cErrMsg           OUTPUT  
                 
         IF @bsuccess <> 1  
         BEGIN  
            SET @nErrNo = 230002   
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetKeyFail'  
            GOTO Quit
         END  

         SELECT TOP 1 @cOrderLineNumber = OrderLineNumber
         FROM dbo.PICKDETAIL PD (NOLOCK)
         WHERE OrderKey = @cOrderkey
         AND StorerKey = @cStorerKey
         AND Sku = @cSKU
         AND (SELECT SUM(qty) FROM dbo.PICKDETAIL (NOLOCK) WHERE OrderKey = @cOrderkey AND StorerKey = @cStorerKey AND Sku = @cSKU) 
            - (SELECT ISNULL(SUM(qty),0) FROM dbo.SerialNo SN (NOLOCK) WHERE SN.OrderKey = PD.OrderKey AND SN.OrderLineNumber = PD.OrderLineNumber AND Storerkey = @cStorerKey) > 0
         ORDER BY OrderLineNumber
            
         INSERT INTO SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty)   
         VALUES (@cSerialNoKey, @cOrderkey,@cOrderLineNumber, @cStorerKey, @cSKU , @cSerialNo , 1)
              
         IF @@ERROR <> 0   
         BEGIN   
            SET @nErrNo = 230003  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsSerialNoFail  
            GOTO Quit    
         END
      END  
   END

Quit:  
  
END  

GO