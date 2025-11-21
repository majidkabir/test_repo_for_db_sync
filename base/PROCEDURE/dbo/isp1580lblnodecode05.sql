SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/  
/* Store procedure: isp1580LblNoDecode05                                      */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Decode SSCC. Return SKU, Qty                                      */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2020-04-21  James     1.0   WMS-12984 Created                              */ 
/* 2020-07-27  YeeKung   1.1   WMS-14410 Add ALtsku and manufacturesku        */
/*                             (yeekung01)                                    */
/******************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp1580LblNoDecode05] (  
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
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Func      INT      
   DECLARE @n_Step      INT      
   DECLARE @n_InputKey  INT      
   DECLARE @n_SKUCnt    INT      
   DECLARE @n_Qty       INT  
   DECLARE @c_ToID         NVARCHAR( 18)  
   DECLARE @c_SKU          NVARCHAR( 20)  
   DECLARE @c_ReceiptGroup NVARCHAR( 20)  
  
     
   IF ISNULL( @c_LabelNo, '') = ''      
      GOTO Quit      
      
   SELECT @n_Func = Func,       
          @n_Step = Step,      
          @n_InputKey = InputKey,  
          @c_ToID = V_ID,  
          @c_ReceiptKey = V_ReceiptKey      
   FROM rdt.rdtMobRec WITH (NOLOCK)       
   WHERE UserName = sUser_sName()      
  
   SELECT @c_ReceiptGroup = ReceiptGroup  
   FROM dbo.RECEIPT WITH (NOLOCK)  
   WHERE ReceiptKey = @c_ReceiptKey  
        
   IF @n_Func = 1580 -- Normal receiving  
   BEGIN  
      IF @n_Step = 5 -- SKU  
      BEGIN  
         IF @n_InputKey = 1 -- ENTER  
         BEGIN  
            SET @c_oFieled01 = ''      
            SET @c_oFieled05 = ''      
     
            SELECT @n_SKUCnt = COUNT( DISTINCT SKU)  
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
            WHERE ReceiptKey = @c_ReceiptKey  
            AND   UserDefine01 = @c_LabelNo  
  
            -- This is a SSCC  
            IF @n_SKUCnt = 1  
            BEGIN  
               SET @c_SKU = ''  
               SET @n_QTY = 0  
  
               SELECT TOP 1 @c_SKU = SKU,   
                            @n_QTY = QtyExpected  
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
               WHERE ReceiptKey = @c_ReceiptKey  
               AND   StorerKey = @c_StorerKey  
               AND   UserDefine01 = @c_LabelNo  
               AND   BeforeReceivedQty = 0  
               ORDER BY 1  
                 
               IF @@ROWCOUNT = 1  
               BEGIN  
                  IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)   
                                  WHERE ReceiptKey = @c_ReceiptKey  
                                  AND   ToId = @c_ToID  
                                  AND   UserDefine01 <> @c_LabelNo)  
                  BEGIN  
                     SET @c_oFieled01 = @c_SKU  
                     SET @c_oFieled05 = @n_QTY  
                  END  
                  ELSE  
                  BEGIN  
                    IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)   
                                 WHERE ReceiptKey = @c_ReceiptKey  
                                 AND   ToId = @c_ToID  
                                 AND   UserDefine01 <> @c_LabelNo)  
                     BEGIN  
                        SET @n_ErrNo = 151201  
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- CASEID IN USED   
                        GOTO Quit  
                     END  
                     --ELSE  
                     --BEGIN  
                     --   SET @n_ErrNo = 151201  
                     --   SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- SSCC RECEIVED   
                     --   GOTO Quit  
                     --END  
                  END  
               END  
               ELSE  
               BEGIN  
                  SET @n_ErrNo = 151202  
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- SSCC RECEIVED   
                  GOTO Quit  
               END  
                 
               GOTO Quit  
            END  
            -- This is a SKU  
            ELSE  
            BEGIN  
               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)  
                           WHERE LISTNAME = 'DSRecGroup'  
                           AND   Code = @c_ReceiptGroup  
                           AND   Short = 'CTN'  
                           AND   Storerkey = @c_Storerkey)  
               BEGIN  
                  
                  SET @n_SKUCnt=0
                  
                  EXEC RDT.rdt_GETSKUCNT        --(yeekung01)
                  @cStorerKey   = @c_Storerkey        
                  ,@cSKU        = @c_LabelNo        
                  ,@nSKUCnt     = @n_SKUCnt      OUTPUT        
                  ,@bSuccess    = @b_Success     OUTPUT        
                  ,@nErr        = @n_ErrNo       OUTPUT        
                  ,@cErrMsg     = @c_ErrMsg      OUTPUT 

                 -- Validate SKU/UPC        
                  IF @n_SKUCnt = 0        
                  BEGIN  
                     SET @n_ErrNo = 151204  
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- invalid SKU   
                     GOTO Quit  
                  END
                  
                 -- Validate SKU/UPC        
                  IF @n_SKUCnt > 1        
                  BEGIN  
                     SET @n_ErrNo = 151205 
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- invalid SKU   
                     GOTO Quit  
                  END
 
                  EXEC [RDT].[rdt_GETSKU]        
                     @cStorerKey  = @c_Storerkey        
                     ,@cSKU        = @c_LabelNo     OUTPUT        
                     ,@bSuccess    = @b_Success     OUTPUT        
                     ,@nErr        = @n_ErrNo       OUTPUT        
                     ,@cErrMsg     = @c_ErrMsg      OUTPUT 

                  IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)  
                                  WHERE ReceiptKey = @c_ReceiptKey  
                                  AND   SKU = @c_LabelNo)  
                  BEGIN  
                     SET @n_ErrNo = 151203  
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- SKU NOT IN ASN   
                     GOTO Quit  
                  END  
               END  
               --ELSE  
               --BEGIN  
               --   SELECT TOP 1 @c_SKU = SKU  
               --   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
               --   WHERE ReceiptKey = @c_ReceiptKey  
               --   AND   ToId = @c_ToID  
               --   ORDER BY 1  
                    
               --   IF @c_LabelNo <> @c_SKU AND ISNULL( @c_SKU, '') <> '' -- Received  
               --   BEGIN  
               --      SET @n_ErrNo = 151204  
               --      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- MIX SKU NOT ALLOW   
               --      GOTO Quit  
               --   END  
               --END  
            END  
  
            SET @c_oFieled01 = @c_LabelNo  
            SET @c_oFieled05 = 1  
         END  
      END  
   END  
  
Quit:  
  
END  

GO