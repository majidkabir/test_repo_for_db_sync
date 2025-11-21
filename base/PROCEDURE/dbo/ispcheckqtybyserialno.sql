SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCheckQtyBySerialNo                              */
/* Creation Date: 13-Oct-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: Validate Qty Entered the same as OrderQty according to      */
/*          SerialNo                                                    */
/*                                                                    	*/
/* Called By: From Pick & Pack Maintenance Screen                       */
/*                                                                      */
/* PVCS Version: 1.1  	                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 16-Mar-2007  Vicky     Change calculation                            */
/* 28-Dec-2007  YokeBeen  SOS#86428 - Added checking on Config setup    */
/*                        to ignore validation of SerialNo if the SP of */
/*                        "ispChkSN" to be applied for StorerConfig     */
/*                        setup - PnPSerialNoCheckCode - (YokeBeen01).  */
/* 09-Jul-2013  NJOW      315487-Extend serialno to char(30)            */
/************************************************************************/

CREATE PROC [dbo].[ispCheckQtyBySerialNo] (
   @cPickSlipNo    NVARCHAR(10),
   @cStorerKey     NVARCHAR(15), 
   @cSKU           NVARCHAR(20),
   @cSerialNo      NVARCHAR(30), 
   @nQty           int,
   @cBUSRFlag      NVARCHAR(1),
   @bSuccess       int = 1 OUTPUT,
   @nErr           int = 0 OUTPUT,
   @cErrmsg        NVARCHAR(250) = '' OUTPUT )
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE 
   @cLoadKey       NVARCHAR(10),
   @cOrderKey      NVARCHAR(10),
   @nSumQty        int,
   @cMonth         NVARCHAR(2),
   @cYear          NVARCHAR(4), 
   @cDay           NVARCHAR(2), 
   @cSQLStatement  nvarchar(2000), 
   @cSQLParms      nvarchar(2000)  

   DECLARE 
   @nStrLength     int,
   @cExpiryDate    NVARCHAR(8)

   SET @bSuccess = 1
   SET @nSumQty = 0
   SET @cMonth = ''
   SET @cYear  = '' 
   SET @cDay = ''
   SET @cExpiryDate = ''

-- 		
--      SELECT '@cSKU', @cSKU
--      SELECT '@cSerialNo', @cSerialNo
--      SELECT '@nQty', @nQty
--      SELECT '@cBUSRFlag', @cBUSRFlag

   SELECT @cLoadKey = ExternOrderKey,
          @cOrderKey = OrderKey 
   FROM   PICKHEADER WITH (NOLOCK)
   WHERE  PickHeaderKey = @cPickSlipNo 

--     SELECT '@cOrderKey', @cOrderKey

   SET @nStrLength = LEN(@cSerialNo) 
     			
   IF ISNULL(dbo.fnc_RTrim(@cOrderKey),'') <> '' 
   BEGIN
      -- (YokeBeen01) - Start 
      IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK) 
                   WHERE configkey = 'PnPSerialNoCheckCode' AND sValue = 'ispChkSN' )
      BEGIN 
	      SELECT @nSumQty = SUM(PD.Qty)
	      FROM PICKDETAIL PD WITH (NOLOCK)
	      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Storerkey = LA.Storerkey AND 
	                                        PD.SKU = LA.SKU AND PD.Lot = LA.Lot)
	      WHERE PD.Orderkey = @cOrderKey
	      AND   PD.SKU = @cSKU
	      AND   PD.Storerkey = @cStorerKey
--          AND   LA.Lottable04 = @cExpiryDate  -- 16-March-2007
	      GROUP BY PD.Orderkey, PD.SKU, PD.Storerkey, LA.Lottable04
      END -- IF EXSITS ispChkSN
      ELSE
      BEGIN -- IF NOT EXSITS ispChkSN
   	   IF @cBUSRFlag = 'N'
	      BEGIN
		      IF @nStrLength = 12 OR @nStrLength = 16 
		      BEGIN   
		         SET @cMonth = SUBSTRING(@cSerialNo, 9, 2) 
   		      SET @cYear  = '20' + SUBSTRING(@cSerialNo, 11, 2) 
		      END 
		      ELSE IF @nStrLength = 14 
		      BEGIN
		         --  If the first character starts with "C" or "N" digit 
		         IF LEFT(@cSerialNo, 1) IN ('C', 'N') 
		         BEGIN
		            SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
		            SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
		         END
		         ELSE
		         BEGIN -- Begin 1st Character Not In ('C', 'N')
		            SET @cYear  = SUBSTRING(@cSerialNo, 8, 4) 
		            SET @cMonth = SUBSTRING(@cSerialNo, 12, 2)             
		
		            IF ISDATE( dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01' ) = 0 
		            BEGIN 
		               SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
		               SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
		            END
		            ELSE 
		            IF CAST(@cYear as int) - DatePart(year, getdate()) > 10 
		            BEGIN 
		               SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
		               SET @cMonth = SUBSTRING(@cSerialNo, 13, 2)            
		            END 
		         END -- End 1st Character Not In ('C', 'N')
		      END 
		   				
		      SET @cExpiryDate = dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01'

--             SELECT '@nSumQty N', @nSumQty
	      END
	      ELSE IF @cBUSRFlag = 'Y'
	      BEGIN
	         IF @nStrLength = 8
            BEGIN
		   	   SET @cYear  = SUBSTRING(@cSerialNo, 5, 4) 
			      SET @cMonth = SUBSTRING(@cSerialNo, 3, 2)             
		         SET @cDay   = SUBSTRING(@cSerialNo, 1, 2)   
		   
		         SET @cExpiryDate = dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + dbo.fnc_RTrim(@cDay)   
		
		    	   IF ISDATE( @cExpiryDate ) = 0 
			      BEGIN
			         SET @nErr = 63002
			         SET @cErrmsg = dbo.fnc_RTrim(@cExpiryDate) + ' Is Not valid Date Format' 
		   	      SET @bSuccess = 0 
			         GOTO QUIT       
			      END 
--SELECT '@cExpiryDate -8', @cExpiryDate
--SELECT '@nSumQty - 8', @nSumQty
            END
            ELSE
            BEGIN 
               IF @nStrLength = 12 OR @nStrLength = 16 
		   	   BEGIN   
			         SET @cMonth = SUBSTRING(@cSerialNo, 9, 2) 
			         SET @cYear  = '20' + SUBSTRING(@cSerialNo, 11, 2) 
		   	   END 
			      ELSE IF @nStrLength = 14 
			      BEGIN
		   	      --  If the first character starts with "C" or "N" digit 
			         IF LEFT(@cSerialNo, 1) IN ('C', 'N') 
			         BEGIN
			            SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
			            SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
		   	      END
			         ELSE
			         BEGIN -- Begin 1st Character Not In ('C', 'N')
		               SET @cYear  = SUBSTRING(@cSerialNo, 8, 4) 
			            SET @cMonth = SUBSTRING(@cSerialNo, 12, 2)             

		   	         IF ISDATE( dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01' ) = 0 
			            BEGIN 
			               SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
			               SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
			            END
			            ELSE 
			            IF CAST(@cYear as int) - DatePart(year, getdate()) > 10 
			            BEGIN 
			               SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
			               SET @cMonth = SUBSTRING(@cSerialNo, 13, 2)            
		   	         END 
			         END -- End 1st Character Not In ('C', 'N')
			      END -- 14
					   				
		         SET @cExpiryDate = dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01'

-- 	 	      SELECT '@cOrderKey - Y', @cOrderKey
-- 		      SELECT '@cExpiryDate - Y', @cExpiryDate
--		         select 'SUMQTY -Y', @nSumQty
            END 
         END -- BUSR = Y

	      SELECT @nSumQty = SUM(PD.Qty)
	      FROM PICKDETAIL PD WITH (NOLOCK)
	      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Storerkey = LA.Storerkey AND 
	                                        PD.SKU = LA.SKU AND PD.Lot = LA.Lot)
	      WHERE PD.Orderkey = @cOrderKey
	      AND   PD.SKU = @cSKU
	      AND   PD.Storerkey = @cStorerKey
         AND   LA.Lottable04 = @cExpiryDate  -- 16-March-2007
	      GROUP BY PD.Orderkey, PD.SKU, PD.Storerkey, LA.Lottable04
      END -- IF NOT EXSITS ispChkSN
      -- (YokeBeen01) - End 
   END -- IF ISNULL(dbo.fnc_RTrim(@cOrderKey),'' <> '' 

   IF ISNULL(@nSumQty,0) = 0 
   BEGIN
      SET @bSuccess = -1
      SET @nErr     = 61566
      SET @cErrmsg  = 'SumQty is invalid' 
      GOTO QUIT 
   END

   IF @nQty > @nSumQty
   BEGIN
      SET @nErr = 64002
		SET @cErrmsg = 'SKU ' + dbo.fnc_RTrim(@cSKU) + ' SerialNo/Expiry Date ' +  dbo.fnc_RTrim(@cSerialNo) + ' Qty Not Tally with QtyAllocated!' 
		SET @bSuccess = 0 
		GOTO QUIT           
   END 
   ELSE
   BEGIN 
      SELECT @bSuccess = 1
   END

   QUIT:
END -- procedure

GO