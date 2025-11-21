SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/***************************************************************************/
/* Store procedure: rdt_727InquiryVLT1                                     */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/*                                                                         */
/* Date            Author     Purposes                                     */
/* 4/29/2024       PPA374     Gives information about ID				   */
/***************************************************************************/
CREATE       PROC [RDT].[rdt_727InquiryVLT1] (
   @nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(60),  
   @cParam2      NVARCHAR(60),  
   @cParam3      NVARCHAR(60),  
   @cParam4      NVARCHAR(60),  
   @cParam5      NVARCHAR(60),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN

   IF @nFunc = 727 and @nStep = 2
   BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0

   DECLARE @ID NVARCHAR(20),
   @LOC NVARCHAR(20),
   @SKU NVARCHAR(20),
   @DESC NVARCHAR(20),
   @LOT NVARCHAR(20),
   @TQTY NVARCHAR(20),
   @IDHOLD NVARCHAR(20),
   @LOCHOLD NVARCHAR(20),
   @LOCFLAG NVARCHAR(20),
   @FACILITY NVARCHAR(20)

   SELECT TOP 1 @FACILITY = FACILITY from rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile

   SET @ID = (select TOP 1 ID from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0)
   SET @LOC = (select TOP 1 LOC from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0)
   SET @SKU = (select TOP 1 SKU from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0)
   SET @DESC = (select TOP 1 DESCR from SKU WITH (NOLOCK) where storerkey = @cStorerKey and SKU = (select SKU from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0))
   SET @LOT = (select TOP 1 LOT from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0)
   SET @TQTY = (select TOP 1 QTY from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0)
   SET @IDHOLD = case when exists (select 1 from INVENTORYHOLD (NOLOCK) where storerkey = @cStorerKey and Hold = 1 and id = @cParam1) then (select TOP 1 Status from inventoryhold (NOLOCK) where storerkey = @cStorerKey and Hold = 1 and id = @cParam1) else 'No Hold' end
   SET @LOCHOLD = case when exists (select 1 from INVENTORYHOLD WITH (NOLOCK) where storerkey = @cStorerKey and Hold = 1 and loc = (select top 1 LOC from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and id = @cParam1 and qty > 0)) then (select TOP 1 Status from inventoryhold (NOLOCK) where storerkey = @cStorerKey and Hold = 1 and loc = (select top 1 LOC from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and id = @cParam1 and qty > 0)) else 'No Hold' end
   SET @LOCFLAG = (select TOP 1 LocationFlag FROM LOC (NOLOCK) where Facility = @Facility and LOC = (select TOP 1 LOC from LOTxLOCxID WITH (NOLOCK) where storerkey = @cStorerKey and ID = @cParam1 and qty > 0))

      BEGIN
         -- Get label
         SET @c_oFieled01 = 'LPN: '+@ID
         SET @c_oFieled02 = 'LOC: '+@LOC
         SET @c_oFieled03 = 'LOT: '+@LOT
         SET @c_oFieled04 = left(trim(@DESC),20)
         SET @c_oFieled05 = 'SKU: '+@SKU
         SET @c_oFieled06 = 'Total QTY: '+convert(NVARCHAR(9),@TQTY)
         SET @c_oFieled07 = 'ID Hold: '+@IDHOLD
         SET @c_oFieled08 = 'Loc Hold: '+@LOCHOLD
         SET @c_oFieled09 = 'Loc Flag: '+@LOCFLAG
         SET @c_oFieled10 = ''
         SET @c_oFieled12 = ''

         --IF @cSKU = @cPreviousSKU
         --BEGIN
            --  SET @nNextPage = 1
         --END
         --ELSE
         --BEGIN
            --  SET @nNextPage = -1  
         --END
      
      END
   Quit:
   END
END -- SP

GO