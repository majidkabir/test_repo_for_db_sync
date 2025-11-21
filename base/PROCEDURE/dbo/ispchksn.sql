SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispChkSN                                           */
/* Creation Date: 27-Dec-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: SOS#86428 - Serial # Validation for Trial Lens              */
/*                                                                   	*/
/*                                                                      */
/* Called By: From ispChkSN base on StorerConfig.sValue                 */
/*            Storerconfig = PnPSerialNoCheckCode                       */ 
/*                                                                      */
/* Parameters:  @cSerialNo is to store direct without validation        */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 09-Jul-2013  NJOW    1.0   315487-Extend serialno to char(30)        */
/************************************************************************/

CREATE PROC [dbo].[ispChkSN] (
   @cLoadKey    NVARCHAR(10),
   @cOrderKey   NVARCHAR(10),
   @cStorerKey  NVARCHAR(15), 
   @cSKU        NVARCHAR(20),
   @nQty        int,
   @cSerialNo   NVARCHAR(30), 
   @bSuccess    int = 1 OUTPUT,
   @nErr        int = 0 OUTPUT,
   @cErrmsg     NVARCHAR(250) = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @bSuccess = 1
   
   IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSerialNo)),'') = '' 
   BEGIN
      SET @cErrmsg = 'Blank Serial No!' 
      SET @bSuccess = 0 
      GOTO QUIT 
   END 

   SET @cSerialNo = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSerialNo)), '')

      -- Validate the PickDetail Here 
      IF ISNULL(dbo.fnc_RTrim(@cOrderKey),'') <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                           FROM PICKDETAIL WITH (NOLOCK)
                           JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( PICKDETAIL.LOT = LOTATTRIBUTE.LOT ) 
                          WHERE PICKDETAIL.OrderKey = @cOrderKey 
                            AND PICKDETAIL.StorerKey = @cStorerKey 
                            AND PICKDETAIL.SKU = @cSKU )
--                             AND LOTATTRIBUTE.Lottable04 = @cSerialNo )
         BEGIN
            SET @nErr = 62003
            SET @cErrmsg = 'Order does not match with the Pick Slip. Please check! ' 
            SET @bSuccess = 0 
            GOTO QUIT    
         END 
      END

   QUIT:   
END


GO