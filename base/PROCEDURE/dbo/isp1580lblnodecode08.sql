SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp1580LblNoDecode08                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 2020-11-17   1.0  YeeKung     WMS15666. Created                      */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp1580LblNoDecode08]  
   @c_LabelNo          NVARCHAR(60),  
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

   DECLARE @cSKU    NVARCHAR( 20)  
   DECLARE @cQTY    NVARCHAR( 5)  
   DECLARE @nFunc   INT
   DECLARE @nStep   INT
   DECLARE @nMobile INT
   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cLottable02 NVARCHAR( 18)
   DECLARE @dLottable04 DATETIME
   DECLARE @cLottable06 NVARCHAR( 30)
   DECLARE @cLangCode   NVARCHAR( 3)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @nInputKey   INT
   DECLARE @nStartPos INT
   DECLARE @nEndPos INT
   DECLARE @cCartonNo NVARCHAR(30)
   DECLARE @nQTY INT
   DECLARE @cSBUSR10 NVARCHAR(10)

   SET @c_oFieled01 = ''
   SET @c_oFieled05 = ''

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @nFunc = Func, 
          @nStep = Step,
          @nMobile = Mobile,
          @cLangCode = Lang_Code,
          @nInputKey = InputKey,
          @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @nFunc IN ( 1580, 1581)
   BEGIN

      IF @nStep = 3
      BEGIN
         SET @c_oFieled01=@c_LabelNo
         GOTO QUIT
      END
      IF @nStep = 5
      BEGIN
         
         IF len(@c_LabelNo)>30
         BEGIN
            IF (CHARINDEX ( '10' , substring(@c_LabelNo,19,8)) =1)
               SET @cLottable01=SUBSTRING( @c_LabelNo, 19, 8) 
                  

            IF ((CHARINDEX ( '[21' , @c_LabelNo) <> 0))  
            BEGIN 
               --cartonno
               SET @nStartPos =CHARINDEX ( '[21' , @c_LabelNo)
               SET @nEndPos =CHARINDEX ( '[240' , @c_LabelNo)

               set @nStartPos=@nStartPos+3

               SET @cCartonNo = SUBSTRING( @c_LabelNo, @nStartPos, @nEndPos - @nStartPos) 

            END
            ELSE
            BEGIN

               SET @nStartPos = 26

               IF (CHARINDEX ( '[240' , @c_LabelNo) <> 0)
                  SET @nEndPos =CHARINDEX ( '[240' , @c_LabelNo)
               ELSE
                  SET @nEndPos =CHARINDEX ( '240' , @c_LabelNo)

               set @nStartPos=@nStartPos+2

               SET @cCartonNo = SUBSTRING( @c_LabelNo, @nStartPos, @nEndPos - @nStartPos) 
            END

            IF ((CHARINDEX ( '[240' , @c_LabelNo) <> 0)) 
            BEGIN
               --sku
               SET @nStartPos =CHARINDEX ( '[240' , @c_LabelNo)

               set @nStartPos=@nStartPos+4

               SET @cSKU = SUBSTRING( @c_LabelNo, @nStartPos, 20) 

               SELECT @nqty=casecnt
               from pack p (NOLOCK)join sku sku (NOLOCK)
               on p.packkey=sku.packkey
               where sku=@cSKU
            END
            ELSE
            BEGIN
               --sku
               SET @nStartPos =CHARINDEX ( '240' , @c_LabelNo)

               set @nStartPos=@nStartPos+3

               SET @cSKU = SUBSTRING( @c_LabelNo, @nStartPos, 20) 

               SELECT @nqty=casecnt
               from pack p (NOLOCK)join sku sku (NOLOCK)
               on p.packkey=sku.packkey
               where sku=@cSKU
            END


            IF NOT EXISTS (SELECT 1 from RECEIPTDETAIL (NOLOCK)
                           WHERE receiptkey=@c_ReceiptKey
                           AND sku=@csku
                           AND storerkey=@c_Storerkey
                           AND lottable01=@cLottable01)
            BEGIN
               SET @n_ErrNo = 162203 
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END

            IF NOT EXISTS (SELECT 1 from ucc (NOLOCK)
                           WHERE uccno=@cCartonNO
                              AND sku=@csku
                              AND storerkey=@c_Storerkey)
            BEGIN

               INSERT INTO dbo.ucc (uccno,storerkey,sku,qty,receiptkey,externkey)
               values(@cCartonNo,@c_Storerkey,@cSKU,@nqty,@c_receiptkey,'')
            END
            ELSE
            BEGIN
               SET @n_ErrNo = 162201 
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END

            SET @c_oFieled01 = @cSKU
            SET @c_oFieled05 = @nqty

         END
         ELSE
         BEGIN

            DECLARE @cSKUInDoc NVARCHAR(20),
                     @nRowCount INT,
                     @cUPC NVARCHAR(20)

            SET @csku=@c_LabelNo 

            SELECT -- TOP 1                
               @cSKUInDoc = A.SKU
            FROM         
            (        
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU.SKU = @cSKU        
               UNION ALL        
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU.AltSKU = @cSKU        
               UNION ALL        
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU.RetailSKU = @cSKU        
               UNION ALL        
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU.ManufacturerSKU = @cSKU        
               UNION ALL        
               SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND UPC.UPC = @cSKU        
            ) A         
            JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = A.StorerKey AND RD.SKU = A.SKU)      
            WHERE receiptkey=@c_ReceiptKey 
            and lottable01=@c_oFieled07
            and lottable02=@c_oFieled08 
            GROUP BY A.StorerKey, A.SKU,RD.qtyexpected

            if @@ROWCOUNT=0
            BEGIN
               SET @n_ErrNo = 162202  
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END

            IF EXISTS (SELECT 1 from SKU (NOLOCK) WHERE sku=@cSKUInDoc and storerkey=@c_Storerkey and busr6 IN ('YES','Y'))
            BEGIN
               SET @n_ErrNo = 162204  
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END

            SELECT @nqty=SUM(p.CaseCnt)
            from pack P (NOLOCK) JOIN sku U (NOLOCK)
            ON P.packkey=U.packkey
            WHERE sku=@cSKUInDoc

            SET @c_oFieled01 = @cSKUInDoc
            SET @c_oFieled05 = @nqty
         END
      END

   END
   QUIT:  
END -- End Procedure  

GO