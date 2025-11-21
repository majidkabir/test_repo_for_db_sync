SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/  
/* Store procedure: rdt_838ExtSNUpd01                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Date        Rev  Author       Purposes                                     */  
/* 24-04-2020  1.0  YeeKung      WMS-12885 Created                             */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_838ExtSNUpd01]  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 3),  
   @cStorerKey       NVARCHAR( 15),  
   @cSKU             NVARCHAR( 20),  
   @nQTY             INT,   
   @cSerialNo        NVARCHAR( 30),  
   @cType            NVARCHAR( 15), --CHECK/INSERT  
   @cDocType         NVARCHAR( 10),   
   @cDocNo           NVARCHAR( 20),   
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount  INT  
   DECLARE @cChkStatus NVARCHAR(10)  
   DECLARE @cChkExternStatus NVARCHAR(10)  
  
   IF @nFunc = 838 -- Pack  
   BEGIN  
      
      DECLARE @cSerialNoKey NVARCHAR(20),
              @cOrderLineNumber INT,
              @bsuccess INT =0,
              @cOrderkey NVARCHAR(20)

      -- Get serial no info  
      SELECT   
         @cChkStatus = Status,   
         @cChkExternStatus = ExternStatus  
      FROM SerialNo WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
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
            SET @nErrNo = 151351   
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetKeyFail'  
            GOTO Quit
         END  

         SELECT @cOrderLineNumber = PD.OrderLineNumber   
               ,@nQty             = PD.Qty 
               ,@cOrderkey        = PD.Orderkey 
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.StorerKey = @cStorerKey  
         AND PD.pickslipno = @cDocNo  
         AND PD.SKU = @cSKU   
         AND PD.Orderlinenumber NOT IN (SELECT  SN.Orderlinenumber
                                        FROM PICKDETAIL PD(NOLOCK) JOIN SerialNo SN (NOLOCK)
                                        ON PD.orderkey=SN.orderkey
                                        WHERE PD.pickslipno = @cDocNo 
                                        AND PD.StorerKey = @cStorerKey  
                                        AND PD.SKU = @cSKU  ) 

         INSERT INTO SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty)   
         VALUES ( @cSerialNoKey, @cOrderkey,@cOrderLineNumber, @cStorerKey, @cSKU , @cSerialNo , 1 )   
  
              
         IF @@ERROR <> 0   
         BEGIN   
            SET @nErrNo = 151352  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsSerialNoFail  
            GOTO Quit    
         END
      END  
   END
           
  
Quit:  
  
END  

GO