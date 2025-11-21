SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_870DecodeLBL01                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Decode Label No Scanned                                     */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 16-03-2015  1.0  ChewKP      SOS#331416 Created                      */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[rdt_870DecodeLBL01]    
   @c_LabelNo          NVARCHAR(40),    
   @c_Storerkey        NVARCHAR(15),    
   @c_ReceiptKey       NVARCHAR(10),    
   @c_POKey            NVARCHAR(10),    
   @c_LangCode         NVARCHAR(3),    
   @c_oFieled01        NVARCHAR(20) OUTPUT,    
   @c_oFieled02        NVARCHAR(20) OUTPUT,    
   @c_oFieled03        NVARCHAR(20) OUTPUT,    
   @c_oFieled04        NVARCHAR(20) OUTPUT,    
   @c_oFieled05        NVARCHAR(20) OUTPUT,    
   @c_oFieled06        NVARCHAR(20) OUTPUT,    
   @c_oFieled07        NVARCHAR(20) OUTPUT,    
   @c_oFieled08        NVARCHAR(20) OUTPUT,    
   @c_oFieled09        NVARCHAR(20) OUTPUT,    
   @c_oFieled10        NVARCHAR(20) OUTPUT,    
   @b_Success          INT = 1  OUTPUT,    
   @n_ErrNo            INT      OUTPUT,    
   @c_ErrMsg           NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nRowCount      INT,   
           @c_PickSlipNo   NVARCHAR(10) ,
           @c_OrderKey     NVARCHAR(10) ,
           @c_SKU          NVARCHAR(20) ,
           @n_Qty          INT
         
   
   SET @c_PickSlipNo = @c_ReceiptKey
   SET @c_oFieled01 = @c_SKU
   SET @n_ErrNo = 0    
   SET @c_ErrMsg = '' 
   SET @c_LangCode = 'ENG'
   
   SELECT @c_OrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickheaderKey = @c_PickSlipNo 
   
    
   SELECT @c_SKU = PD.SKU
         ,@n_Qty = SUM(PD.Qty)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = PD.Lot AND LA.SKU = PD.SKU)
   WHERE PD.StorerKey   = @c_Storerkey
   AND PD.OrderKey      = @c_OrderKey
   AND LA.Lottable02    = @c_LabelNo
   GROUP BY PD.SKU 
   
   IF ISNULL(RTRIM(@c_SKU),'')  = ''
   BEGIN                      
        SET @n_ErrNo = 93101
        SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InvalidSerialNo'
        GOTO QUIT
        
   END
   ELSE
   BEGIN
      SET @c_oFieled01 = @c_SKU    
      SET @c_oFieled05 = @n_Qty  
   END
     
    
    
   --COMMIT TRAN rdt_1765DecodeLBL01    
   --GOTO Quit    
    
--RollBackTran:    
--   ROLLBACK TRAN rdt_1765DecodeLBL01    
Quit:    
--   WHILE @@TRANCOUNT > @nTranCount    
--      COMMIT TRAN    
END -- End Procedure    

SET QUOTED_IDENTIFIER OFF

GO