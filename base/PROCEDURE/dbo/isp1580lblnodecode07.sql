SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp1580LblNoDecode07                                */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 2020-08-17   1.0  Ung         WMS-14788 Created                      */  
/* 2020-09-04   1.1  Ung         WMS-14788 Add check SerialNoCapture    */
/* 2020-09-28   1.2  Chermaine   WMS-15315 remove serial.status=9 checking(cc01)*/
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp1580LblNoDecode07]  
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
   @b_Success          INT = 1      OUTPUT,  
   @n_ErrNo            INT          OUTPUT,   
   @c_ErrMsg           NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   -- Get session info
   DECLARE @nFunc INT
   DECLARE @nStep INT
   DECLARE @cLangCode NVARCHAR( 3)
   DECLARE @cUCC      NVARCHAR( 20) --(cc01)
   SELECT 
      @nFunc = Func, 
      @nStep = Step, 
      @cLangCode = Lang_Code
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()

   IF @nFunc IN (1580, 1581) -- Piece receiving
   BEGIN
      IF @nStep = 5 -- SKU
      BEGIN
         DECLARE @nRowCount INT
         DECLARE @cSKU      NVARCHAR(20) = ''
         DECLARE @cStatus   NVARCHAR(10)

         -- Get serial info
         SELECT 
            @cSKU = SKU, 
            @cStatus = STATUS,
            @cUCC = UCCNo
         FROM SerialNo WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND SerialNo = @c_LabelNo

         SET @nRowCount = @@ROWCOUNT 
         
         IF @nRowCount = 1
         BEGIN
            -- Check status
            IF @cStatus NOT IN ('0','9')
            BEGIN
               IF @cStatus = '1' 
                  SELECT @n_ErrNo = 158751, @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') -- SNO received
               ELSE IF @cStatus = '5' 
                  SELECT @n_ErrNo = 158752, @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') -- SNO picked
               ELSE IF @cStatus = '6' 
                  SELECT @n_ErrNo = 158753, @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') -- SNO packed
               --ELSE IF @cStatus = '9' 
                  --SELECT @n_ErrNo = 158754, @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') -- SNO shipped               
               ELSE
                  SELECT @n_ErrNo = 158755, @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') -- SNO bad status     
               GOTO Quit
            END
            
            IF @cStatus = '9'
            BEGIN
            	UPDATE SerialNo SET [status] = '1' WHERE StorerKey = @c_StorerKey AND SerialNo = @c_LabelNo
            END

            IF NOT EXISTS( SELECT 1 
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @c_Storerkey 
                  AND SKU = @cSKU 
                  AND SerialNoCapture IN ('1', '2'))-- 1=inbound and outbound, 2=inbound only
            BEGIN
               SET @n_ErrNo = 158756
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --SKU SNOCap Off
               GOTO Quit
            END

            SET @c_oFieled01 = @cSKU      -- SKU
            SET @c_oFieled02 = @c_LabelNo -- SerialNo
            SET @c_oFieled05 = '1'        -- QTY
         END
         
         -- Check not serial no
         ELSE IF @nRowCount = 0
         BEGIN
            SET @n_ErrNo = 158757
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Not a SNO
            GOTO Quit
         END

         -- Check duplicate serialno
         ELSE
         BEGIN
            SET @n_ErrNo = 158758
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Duplicate SNO
            GOTO Quit
         END
      END
   END

Quit:

END

GO