SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispTBLHK_ExportShipConfirm : 
--

/* 28-Jan-2019  TLTING_ext 2.9  enlarge externorderkey field length              */
/* 23-Mar-2021  WLChooi    3.0  Remove Harcoded DB Name (WL01)                   */

CREATE PROC [dbo].[ispTBLHK_ExportShipConfirm] (
	@c_openflag  NVARCHAR(1),
   @c_storerkey  NVARCHAR(15)
)
AS	
	-- Created by YokeBeen on 3-Apr-2003 - (FBR10622 / SOS#10622)
	-- Ship Confirmation Outbound for Timberland HongKong.
	-- Insert candidate records into table TBLSHPCONFx on DTSITF db. (x = 1/2/3/4/5)
	-- Modified By SHONG on 29-Jul-2003
	-- Purge Old Records to Regenerate again.
	-- Modified by June  on 25-Nov-2004 : SOS29742
	-- Link by index key

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
	DECLARE @c_key			 NVARCHAR(10),
           @b_success		INT,
           @c_tblpickctl NVARCHAR(15),
           @n_err				INT, 
           @c_errmsg		 NVARCHAR(255), 
			  @c_ExternOrderkey NVARCHAR(50),   --tlting_ext
			  @n_TotCount		INT, 
			  @n_CountLay1		INT, 
			  @n_CountLay2		INT, 
			  @n_CountLay3		INT, 
			  @n_CountLay4		INT, 
           @b_debug int,
           @n_continue INT

	SELECT @b_debug = 0
	SELECT @n_continue = 1	
	SELECT @c_key = ''

	WHILE (1=1)
	BEGIN
		SELECT @c_key = MIN(key1) --, 
--				 @c_ExternOrderkey = ORDERS.ExternOrderkey
		FROM   TRANSMITLOG2 TRANSMITLOG2 (NOLOCK)   --WL01
      JOIN   ORDERS ORDERS (NOLOCK) ON (ORDERS.Orderkey = TRANSMITLOG2.Key1   --WL01
															 AND ORDERS.Storerkey = TRANSMITLOG2.Key3
														 	 AND ORDERS.Storerkey = @c_storerkey )
		WHERE  TRANSMITLOG2.Transmitflag = '1'
			AND TRANSMITLOG2.Tablename = 'TBLHKSHP'
			AND TRANSMITLOG2.Key1 > @c_key
--		GROUP BY ORDERS.ExternOrderkey

		IF @@ROWCOUNT = 0 OR @c_key IS NULL
			BREAK

      SELECT @c_externorderkey = externorderkey 
      FROM   orders (nolock)   --WL01
		WHERE  orderkey = @c_key
		IF @b_debug = 1
		BEGIN
			select 'Orderkey' = @c_key, 'ExternOrderkey'= @c_ExternOrderkey
		END

      -- Added By SHONG on 29th Jul 2003
      -- Purge the generated temp exported file 
		IF EXISTS (SELECT 1 FROM TBLSHPCONF1 (NOLOCK) WHERE ISPKTN = @c_ExternOrderkey)
      BEGIN
         DELETE FROM TBLSHPCONF1 
         WHERE ISPKTN = @c_ExternOrderkey

         DELETE TBLSHPCONF3 
         FROM TBLSHPCONF3 
         JOIN TBLSHPCONF2 ON (TBLSHPCONF3.ISPCTL = TBLSHPCONF2.ISPCTL)
         WHERE TBLSHPCONF2.ISPKTN = @c_ExternOrderkey

         DELETE FROM TBLSHPCONF4 
         WHERE TBLSHPCONF4.ISPKTN = @c_ExternOrderkey

         DELETE TBLSHPCONF5 
         FROM TBLSHPCONF5 
         JOIN TBLSHPCONF2 ON (TBLSHPCONF5.ISPCTL = TBLSHPCONF2.ISPCTL)
         WHERE TBLSHPCONF2.ISPKTN = @c_ExternOrderkey

         DELETE FROM TBLSHPCONF2 
         WHERE ISPKTN = @c_ExternOrderkey
      END 

		-- Check on existing record.  Insert into Layout files if not exists - TBLSHPCONFx
		IF NOT EXISTS (SELECT 1 FROM TBLSHPCONF1 (NOLOCK) WHERE ISPKTN = @c_ExternOrderkey)
		BEGIN
         SELECT @c_tblpickctl = ''
         SELECT @b_success = 0

         EXECUTE nspg_getkey
         'TBLPICKCTL'
         , 6
         , @c_tblpickctl OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT

			-- Insert into TBLSHPCONF1 - Layout 0.
         BEGIN TRAN
			INSERT INTO TBLSHPCONF1 (ISPCTL, ISPKTN, ICWHSE, ICSHDT, ISSOUC) 
			SELECT DISTINCT RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(6), @c_tblpickctl))), 6), 
               LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),
					 CONVERT(NCHAR(3), RIGHT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(Facility.userdefine05)), 3)),   
					 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(MBOL.DepartureDate , 0), 112), 9),  
					 TRANSMITLOG2.TransmitLogKey 
			  FROM MBOL MBOL (NOLOCK)   --WL01 
			  JOIN MBOLDETAIL MBOLDETAIL (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)   --WL01
			  JOIN ORDERS ORDERS (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey   --WL01
			  																 -- Start: SOS29742
			  		  														 AND MBOLDETAIL.Mbolkey = ORDERS.Mbolkey)
			  		  														 -- End: SOS29742	
           JOIN Facility Facility (NOLOCK) ON (ORDERS.Facility = FACILITY.facility)   --WL01
			  JOIN TRANSMITLOG2 TRANSMITLOG2 (NOLOCK) ON (ORDERS.OrderKey = TRANSMITLOG2.Key1   --WL01 
																				 AND ORDERS.StorerKey = TRANSMITLOG2.Key3) 
			  JOIN ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)   --WL01
			 WHERE MBOLDETAIL.OrderKey = @c_key 
				AND ORDERS.StorerKey = @c_storerkey 
				AND ORDERS.ExternOrderKey = @c_ExternOrderkey 
				AND TRANSMITLOG2.TableName = 'TBLHKSHP'
			GROUP BY -- RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(CHAR(6), '20'))), 6), 
               LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),
					 CONVERT(NCHAR(3), RIGHT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(Facility.userdefine05)), 3)),   
					 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(MBOL.DepartureDate , 0), 112), 9),  
					 TRANSMITLOG2.TransmitLogKey 
			HAVING SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) > 0

         IF @@ERROR = 0
         BEGIN 
            COMMIT TRAN
         END
         ELSE
         BEGIN
            Rollback tran
            select @n_continue = 3
         END	
         
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            BEGIN TRAN
				-- Insert into TBLSHPCONF2 - Layout 1.
				INSERT INTO TBLSHPCONF2 (ISPCTL, I1WHSE, ISPKTN, I1ORDN, I1OTYP, I1SHTO, I1SOTO, I1SVIA, I1PGDT, I1PPDT, I1SDDT, 
												 I1SHDT, I1CUPO, I1PRON, I1ARAC, I1WGHT, I1SQTY, I1TCT, I1TLIN, I1HWC, I1BLAD, I1PRVL, 
												 I1SCHG, I1HCHG, I1INCH, I1TXCH, I1MSCH, I1ZSSC, I1NUM1, I1NUM2, I1NUM3, I1PRDT, I1PRTM, 
												 I1DCR, I1TCR) 
				SELECT RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(6), @c_tblpickctl))), 6), 
						 CONVERT(NCHAR(3), RIGHT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(Facility.userdefine05)), 3)), 
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.InvoiceNo , ' ')))) + REPLICATE(' ', 8), 8),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(2), ISNULL(ORDERS.Type , ' ')))) + REPLICATE(' ', 2), 2),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.Userdefine10 , ' ')))) + REPLICATE(' ', 8), 8),  -- shipto key
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.BillToKey , ' ')))) + REPLICATE(' ', 8), 8),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(ORDERS.Route , ' ')))) + REPLICATE(' ', 4), 4),  
						 REPLICATE('0', 9),  
						 REPLICATE('0', 9),  
						 REPLICATE('0', 9),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(MBOL.DepartureDate , '0'), 112), 9),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(26), ISNULL(ORDERS.BuyerPO , ' ')))) + REPLICATE(' ', 26), 26),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(MBOL.VoyageNumber , ' ')))) + REPLICATE(' ', 20), 20),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.Userdefine01 , ' ')))) + REPLICATE(' ', 10), 10),  
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), MIN(( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.NetWgt))) ))), 7) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(11,2), MIN( (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.NetWgt)), 2) ), 2) , 
						 RIGHT(REPLICATE('0', 9) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(9), FLOOR(CONVERT(DECIMAL(11,2), MIN( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty))) ))), 9) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(11,2), MIN(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)), 2) ), 2) , 
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), CONVERT(DECIMAL(7,0), MAX(PACKDETAIL.CartonNo))) )), 7), 
						 RIGHT(REPLICATE('0', 5) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), CONVERT(DECIMAL(5,0), MAX(ORDERDETAIL.OrderLineNumber))) )), 5), 
						 REPLICATE('0', 11),  
						 RIGHT(REPLICATE(' ', 10) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.MbolKey , ' ')))), 10),  
						 RIGHT(REPLICATE('0', 9) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(9), FLOOR(CONVERT(DECIMAL(11,2), MIN( (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.StdOrderCost))) ))), 9) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(11,2), MIN( (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.StdOrderCost)), 2) ), 2) , 
						 REPLICATE('0', 11),  
						 REPLICATE('0', 11),  
						 REPLICATE('0', 11),  
						 REPLICATE('0', 11),  
						 REPLICATE('0', 11),  
						 REPLICATE('0', 11),  
						 REPLICATE('0', 13),  
						 REPLICATE('0', 13),  
						 REPLICATE('0', 13),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(LOADPLAN.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 7, 2), 2) ),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(ORDERS.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 7, 2), 2) )  
				  FROM MBOL MBOL (NOLOCK)   --WL01 
				  JOIN MBOLDETAIL MBOLDETAIL (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)   --WL01
				  JOIN ORDERS ORDERS (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey   --WL01
				  																-- Start: SOS29742
				  			  													AND MBOLDETAIL.Mbolkey = ORDERS.Mbolkey)			  																  
																				-- End: SOS29742
	           JOiN FACILITY FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)   --WL01
				  JOIN ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)   --WL01 
				  																  -- Start: SOS29742
				  																  -- AND ORDERS.StorerKey = ORDERDETAIL.StorerKey)
																				  -- End: SOS29742
				  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)   --WL01
				  																-- Start: SOS29742
																				-- AND ORDERS.StorerKey = PACKHEADER.StorerKey)
																				-- End: SOS29742
				  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   --WL01
				  																-- Start: SOS29742
																				-- AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey)
																				-- End: SOS29742
				  JOIN LOADPLAN LOADPLAN (NOLOCK) ON (ORDERDETAIL.LoadKey = LOADPLAN.LoadKey)   --WL01 
				  JOIN SKU SKU (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku   --WL01
															 AND ORDERDETAIL.StorerKey = SKU.StorerKey) 
				 WHERE MBOLDETAIL.OrderKey = @c_key 
					AND ORDERS.StorerKey = @c_storerkey 
					AND ORDERS.ExternOrderKey = @c_ExternOrderkey 
				GROUP by CONVERT(NCHAR(3), RIGHT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(FACILITY.Userdefine05)), 3)), 
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.InvoiceNo , ' ')))) + REPLICATE(' ', 8), 8),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(2), ISNULL(ORDERS.Type , ' ')))) + REPLICATE(' ', 2), 2),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.Userdefine10 , ' ')))) + REPLICATE(' ', 8), 8),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.BillToKey , ' ')))) + REPLICATE(' ', 8), 8),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(ORDERS.Route , ' ')))) + REPLICATE(' ', 4), 4),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(MBOL.DepartureDate , '0'), 112), 9),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(26), ISNULL(ORDERS.BuyerPO , ' ')))) + REPLICATE(' ', 26), 26),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(MBOL.VoyageNumber , ' ')))) + REPLICATE(' ', 20), 20),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.Userdefine01 , ' ')))) + REPLICATE(' ', 10), 10),  
						 RIGHT(REPLICATE(' ', 10) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.MbolKey , ' ')))), 10),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(LOADPLAN.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 7, 2), 2) ),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(ORDERS.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERS.AddDate, 108), 7, 2), 2) )  
				HAVING SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) > 0

				IF @@ERROR = 0
				BEGIN 
					COMMIT TRAN
				END
				ELSE
				BEGIN
					Rollback tran
					select @n_continue = 3
				END	
	      END -- Insert into TBLSHPCONF2 - Layout 1.

			IF @n_continue = 1 OR @n_continue  = 2
			BEGIN
	         BEGIN TRAN
			-- Insert into TBLSHPCONF3 - Layout 2.
				INSERT INTO TBLSHPCONF3 (ISPCTL, ISPKLN, I2SZPO, I2STYL, I2COLR, I2SDIM, I2QUAL, I2PIQT, I2PAKU, I2SZCD, I2PRED, 
												 I2VEND, I2SERP, I2PSTD, I2NUM1, I2NUM2, I2NUM3, I2NUM4, I2NUM5, I2PRDT, I2PRTM, I2DCR, 
												 I2TCR) 
				SELECT RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(6), @c_tblpickctl))), 6), 
						 RIGHT(REPLICATE('0', 5) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), CONVERT(DECIMAL(5,0), ISNULL(ORDERDETAIL.ExternLineNo , 0)) ))), 5),  
						 RIGHT(REPLICATE('0', 2) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(2), CONVERT(DECIMAL(2,0), ISNULL(ORDERDETAIL.Tax01 , 0)) ))), 2),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 1, 8) ))) + REPLICATE(' ', 8), 8), -- style
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 9, 3) ))) + REPLICATE(' ', 4), 4),  -- color
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 12, 3) ))) + REPLICATE(' ', 3), 3), -- dimension
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 15, 1) ))) + REPLICATE(' ', 1), 1), --quality
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), ORDERDETAIL.OriginalQty)) ))), 7) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), ORDERDETAIL.OriginalQty), 2) ), 2) , -- i2piqt
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)) ))), 7) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty), 2) ), 2) , --i2paku
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(SKU.BUSR2 , ' ') ))) + REPLICATE(' ', 4), 4),  --i2szcd size range code
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), LEFT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 2, 5) ))) + REPLICATE(' ', 5), 5),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 7, 5) ))) + REPLICATE(' ', 5), 5),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), RIGHT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
						 REPLICATE('0', 9),  
						 REPLICATE('0', 9),  
						 REPLICATE('0', 9),  
						 REPLICATE('0', 13),  
						 REPLICATE('0', 13),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(LOADPLAN.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 7, 2), 2) ),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(ORDERDETAIL.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 7, 2), 2) )  
				  FROM ORDERDETAIL ORDERDETAIL (NOLOCK)   --WL01 
				  JOIN LOADPLAN LOADPLAN (NOLOCK) ON (ORDERDETAIL.LoadKey = LOADPLAN.LoadKey)   --WL01 
				  JOIN SKU SKU (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku   --WL01
															 AND ORDERDETAIL.StorerKey = SKU.StorerKey) 
				 WHERE ORDERDETAIL.OrderKey = @c_key 
					AND ORDERDETAIL.StorerKey = @c_storerkey 
					AND ORDERDETAIL.ExternOrderKey = @c_ExternOrderkey 
					GROUP BY RIGHT(REPLICATE('0', 5) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), CONVERT(DECIMAL(5,0), ISNULL(ORDERDETAIL.ExternLineNo , 0)) ))), 5),  
						 RIGHT(REPLICATE('0', 2) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(2), CONVERT(DECIMAL(2,0), ISNULL(ORDERDETAIL.Tax01 , 0)) ))), 2),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 1, 8) ))) + REPLICATE(' ', 8), 8), -- style
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 9, 3) ))) + REPLICATE(' ', 4), 4),  -- color
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 12, 3) ))) + REPLICATE(' ', 3), 3), -- dimension
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 15, 1) ))) + REPLICATE(' ', 1), 1), --quality
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), ORDERDETAIL.OriginalQty)) ))), 7) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), ORDERDETAIL.OriginalQty), 2) ), 2) , -- i2piqt
						 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)) ))), 7) + 
								RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty), 2) ), 2) , --i2paku
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(SKU.BUSR2 , ' ') ))) + REPLICATE(' ', 4), 4),  --i2szcd size range code
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), LEFT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 2, 5) ))) + REPLICATE(' ', 5), 5),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 7, 5) ))) + REPLICATE(' ', 5), 5),  
						 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), RIGHT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(LOADPLAN.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), LOADPLAN.AddDate, 108), 7, 2), 2) ),  
						 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(ORDERDETAIL.AddDate , 0), 112), 9),  
						 CONVERT(NCHAR(7), '0' + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 1, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 4, 2), 2) + 
								RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), ORDERDETAIL.AddDate, 108), 7, 2), 2) )  
				 HAVING SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) > 0

         IF @@ERROR = 0
         BEGIN 
            COMMIT TRAN
         END
         ELSE
         BEGIN
            Rollback tran
            select @n_continue = 3
         END		
      END -- Insert into TBLSHPCONF3 - Layout 2.

      IF @n_continue = 1 OR @n_continue  = 2
      BEGIN
         BEGIN TRAN

		-- Insert into TBLSHPCONF4 - Layout 3.
			INSERT INTO TBLSHPCONF4 (I3CASN, ISPCTL, ISPKTN, I3ORDN, I3SOTO, I3SHTO, I3CUPO, I3TRKN, I3LNTH, I3WDTH, 
											 I3HGHT, I3CTVL, I3ESWT, I3ACWT, I3TQTY, I3TQTS, I3SCHG, I3CASE, I3BLAD, I3SVIA, 
											 I3ACHG, I3APDT, I3LSEQ, I3NUM1, I3NUM2, I3PRDT, I3PRTM, I3DCR, I3TCR) 
			SELECT LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(PACKDETAIL.LabelNo , ' ')))) + REPLICATE(' ', 20), 20),  
					 RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(6), @c_tblpickctl))), 6), 
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.InvoiceNo , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.Userdefine10 , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.BillToKey , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(26), ISNULL(ORDERS.BuyerPO , ' ')))) + REPLICATE(' ', 26), 26),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(30), ISNULL(MBOL.VoyageNumber , ' ')))) + REPLICATE(' ', 30), 30),  
					 REPLICATE('0', 7),  
					 REPLICATE('0', 7),  
					 REPLICATE('0', 7),  
					 REPLICATE('0', 9),  
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt)) ))), 7) + 
							RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt), 2) ), 2) , 
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt)) ))), 7) + 
							RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt), 2) ), 2) , 
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), SUM(PACKDETAIL.Qty))) ))), 7) + 
							RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), SUM(PACKDETAIL.Qty)), 2) ), 2) , 
					 CASE WHEN (CONVERT(DECIMAL(9,2), SUM(PACKDETAIL.Qty)) >= 0) THEN '0' 
							ELSE '1' END, 
					 REPLICATE('0', 11),  
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), CONVERT(DECIMAL(7,0), PACKDETAIL.CartonNo)) )), 7), 
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.MBOLKey , ' ')))) + REPLICATE(' ', 10), 10),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(ORDERS.UserDefine03 , ' ')))) + REPLICATE(' ', 4), 4),  
					 REPLICATE('0', 1),  
					 CONVERT(NCHAR(9), '0' + CONVERT(NCHAR(9), MAX(PACKDETAIL.EditDate), 112)), 
					 REPLICATE('0', 5),  
					 REPLICATE('0', 5),  
					 REPLICATE('0', 5),  
					 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(max(PACKDETAIL.EditDate) , 0), 112), 9),  
					 CONVERT(NCHAR(7), '0' + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.EditDate), 108), 1, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.EditDate), 108), 4, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.EditDate), 108), 7, 2), 2) ),  
					 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(max(PACKDETAIL.AddDate) , 0), 112), 9),  
					 CONVERT(NCHAR(7), '0' + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.AddDate), 108), 1, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.AddDate), 108), 4, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), max(PACKDETAIL.AddDate), 108), 7, 2), 2) )  
			  FROM ORDERS ORDERS (NOLOCK)   --WL01 
			  JOIN ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)   --WL01
			  																  -- Start: SOS29742
																			  -- AND ORDERS.StorerKey = ORDERDETAIL.StorerKey)
																			  -- End: SOS29742
			  JOIN MBOL MBOL (NOLOCK) ON (ORDERS.MbolKey = MBOL.MbolKey)   --WL01
			  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)   --WL01
			  																-- Start: SOS29742 
																			-- AND ORDERS.StorerKey = PACKHEADER.StorerKey)
																			-- End: SOS29742 
			  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   --WL01
			  																-- Start: SOS29742 
																			-- AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey)
																			-- End: SOS29742 
			  JOIN SKU SKU (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku   --WL01
														 AND ORDERDETAIL.StorerKey = SKU.StorerKey) 
			 WHERE ORDERDETAIL.OrderKey = @c_key 
				AND ORDERDETAIL.StorerKey = @c_storerkey 
				AND ORDERDETAIL.ExternOrderKey = @c_ExternOrderkey 
			GROUP BY LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(PACKDETAIL.LabelNo , ' ')))) + REPLICATE(' ', 20), 20),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(11), ISNULL(ORDERS.ExternOrderKey , ' ')))) + REPLICATE(' ', 11), 11),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.InvoiceNo , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.userdefine10 , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), ISNULL(ORDERS.BillToKey , ' ')))) + REPLICATE(' ', 8), 8),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(26), ISNULL(ORDERS.BuyerPO , ' ')))) + REPLICATE(' ', 26), 26),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(30), ISNULL(MBOL.VoyageNumber , ' ')))) + REPLICATE(' ', 30), 30),  
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt)) ))), 7) + 
							RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt), 2) ), 2) , 
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt)) ))), 7) + 
							RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), PACKDETAIL.Qty * SKU.NetWgt), 2) ), 2) , 
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(10), ISNULL(ORDERS.MBOLKey , ' ')))) + REPLICATE(' ', 10), 10),  
					 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(ORDERS.UserDefine03 , ' ')))) + REPLICATE(' ', 4), 4),  
--					 RIGHT(REPLICATE('0', 9) + CONVERT(CHAR(8), ISNULL(PACKDETAIL.EditDate , 0), 112), 9),  
					 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), CONVERT(DECIMAL(7,0), PACKDETAIL.CartonNo)) )), 7)
--					 RIGHT(REPLICATE('0', 9) + CONVERT(CHAR(8), ISNULL(PACKDETAIL.AddDate , 0), 112), 9)
					HAVING SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHippedQty) > 0
/*
					 CONVERT(CHAR(7), '0' + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.EditDate, 108), 1, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.EditDate, 108), 4, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.EditDate, 108), 7, 2), 2) ),  

					 CONVERT(CHAR(7), '0' + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.AddDate, 108), 1, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.AddDate, 108), 4, 2), 2) + 
							RIGHT('0' + SUBSTRING(CONVERT(CHAR(7), PACKDETAIL.AddDate, 108), 7, 2), 2) )  
*/

         IF @@ERROR = 0
         BEGIN 
            COMMIT TRAN
         END
         ELSE
         BEGIN
            Rollback tran
            select @n_continue = 3
         END	
      END -- Insert into TBLSHPCONF4 - Layout 3.

      IF @n_continue = 1 OR @n_continue  = 2
      BEGIN
         BEGIN TRAN

			-- Insert into TBLSHPCONF5 - Layout 4.
			INSERT INTO TBLSHPCONF5 (ISPCTL, I4CASN, ISPKLN, I4SZPO, I4CTLN, I4STYL, I4COLR, I4SDIM, I4QUAL, I4SZCD, 
											 I4SZDS, I4CSKU, I4PRED, I4VEND, I4SERP, I4PSTD, I4PAKU, I4PAKB, I4NUM1, I4NUM2, 
											 I4PRDT, I4PRTM, I4DCR, I4TCR) 

			SELECT RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(6), @c_tblpickctl ))), 6), 
							 LEFT(CONVERT(NCHAR(20), dbo.fnc_LTRIM(dbo.fnc_RTRIM(PACKDETAIL.LabelNo))) + REPLICATE(' ', 20), 20), 
							 RIGHT(REPLICATE('0', 5) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), CONVERT(DECIMAL(5,0), ISNULL(PACKDETAIL.LabelLine , 0)) ))), 5),  
							 RIGHT(REPLICATE('0', 2) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(2), CONVERT(DECIMAL(2,0), 0 ) ))), 2),  
							 RIGHT(REPLICATE('0', 3) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), CONVERT(DECIMAL(3,0), ISNULL(PACKDETAIL.LabelLine , 0)) ))), 3),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 1, 8) ))) + REPLICATE(' ', 8), 8),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 9, 3) ))) + REPLICATE(' ', 4), 4),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 12, 3) ))) + REPLICATE(' ', 3), 3),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 15, 1) ))) + REPLICATE(' ', 1), 1),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(SKU.BUSR2 , ' ')))) + REPLICATE(' ', 4), 4),  -- size range code
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 16, 5) ))) + REPLICATE(' ', 4), 4),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(SKU.RetailSKU , ' ')))) + REPLICATE(' ', 20), 20),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), LEFT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 2, 5) ))) + REPLICATE(' ', 5), 5),  --i4vend
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 7, 5) ))) + REPLICATE(' ', 5), 5),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), RIGHT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
							 RIGHT(REPLICATE('0', 7) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(7), FLOOR(CONVERT(DECIMAL(9,2), sum(PACKDETAIL.Qty))) ))), 7) + 
									RIGHT(REPLICATE('0', 2) + CONVERT(NCHAR(2), RIGHT(CONVERT(DECIMAL(9,2), sum(PACKDETAIL.Qty)), 2) ), 2)  , 
							 REPLICATE('0', 7),  
							 REPLICATE('0', 5),  
							 REPLICATE('0', 5),  
							 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(PACKDETAIL.EditDate , 0), 112), 9),  
							 CONVERT(NCHAR(7), '0' + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 1, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 4, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 7, 2), 2) ),  
							 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(PACKDETAIL.AddDate , 0), 112), 9),  
							 CONVERT(NCHAR(7), '0' + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 1, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 4, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 7, 2), 2) )  
					  FROM PACKDETAIL PACKDETAIL (NOLOCK)   --WL01
					  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   --WL01
					  																-- Start: SOS29742  
																					-- AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
																					-- End: SOS29742 
					  JOIN ORDERS ORDERS (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)   --WL01
					  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.SKU = SKU.Sku   --WL01
																 AND PACKDETAIL.StorerKey = SKU.StorerKey) 
					  WHERE ORDERS.OrderKey = @c_key 
						AND ORDERS.StorerKey = @c_storerkey 
						AND ORDERS.ExternOrderKey = @c_ExternOrderkey 
		          GROUP BY --RIGHT(REPLICATE('0', 6) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(CHAR(6), @c_tblpickctl))), 6), 
							 LEFT(CONVERT(NCHAR(20), dbo.fnc_LTRIM(dbo.fnc_RTRIM(PACKDETAIL.LabelNo))) + REPLICATE(' ', 20), 20), 
							 RIGHT(REPLICATE('0', 5) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), CONVERT(DECIMAL(5,0), ISNULL(PACKDETAIL.LabelLine, 0)) ))), 5),   
							 RIGHT(REPLICATE('0', 3) + dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), CONVERT(DECIMAL(3,0), ISNULL(PACKDETAIL.LabelLine , 0)) ))), 3),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(8), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 1, 8) ))) + REPLICATE(' ', 8), 8),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 9, 3) ))) + REPLICATE(' ', 4), 4),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(3), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 12, 3) ))) + REPLICATE(' ', 3), 3),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 15, 1) ))) + REPLICATE(' ', 1), 1),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), ISNULL(SKU.BUSR2 , ' ')))) + REPLICATE(' ', 4), 4),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(4), SUBSTRING(ISNULL(SKU.BUSR1 , ' '), 16, 5) ))) + REPLICATE(' ', 4), 4),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(20), ISNULL(SKU.RetailSKU , ' ')))) + REPLICATE(' ', 20), 20),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), LEFT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 2, 5) ))) + REPLICATE(' ', 5), 5),  --i4vend
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(5), SUBSTRING(ISNULL(SKU.RetailSku , ' '), 7, 5) ))) + REPLICATE(' ', 5), 5),  
							 LEFT(dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(NCHAR(1), RIGHT(ISNULL(SKU.RetailSku , ' '), 1) ))) + REPLICATE(' ', 1), 1),  
							 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(PACKDETAIL.EditDate , 0), 112), 9),  
							 CONVERT(NCHAR(7), '0' + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 1, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 4, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.EditDate, 108), 7, 2), 2) ),  
							 RIGHT(REPLICATE('0', 9) + CONVERT(NCHAR(8), ISNULL(PACKDETAIL.AddDate , 0), 112), 9),  
							 CONVERT(NCHAR(7), '0' + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 1, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 4, 2), 2) + 
									RIGHT('0' + SUBSTRING(CONVERT(NCHAR(7), PACKDETAIL.AddDate, 108), 7, 2), 2) )		
		
         IF @@ERROR = 0
         BEGIN 
            COMMIT TRAN
         END
         ELSE
         BEGIN
            Rollback tran
		     select @n_continue = 3
         END	
      END -- Insert into TBLSHPCONF5 - Layout 4.

      IF @n_continue = 1 OR @n_continue  = 2
      BEGIN
			-- Update the TBLSHPCONF1 (Layout 0) on total records from Detail Layout 1,2,3 and 4.
			SELECT @n_CountLay1 = COUNT(*) FROM TBLSHPCONF2 (NOLOCK) WHERE ISPCTL = @c_tblpickctl
			SELECT @n_CountLay2 = COUNT(*) FROM TBLSHPCONF3 (NOLOCK) WHERE ISPCTL = @c_tblpickctl
			SELECT @n_CountLay3 = COUNT(*) FROM TBLSHPCONF4 (NOLOCK) WHERE ISPCTL = @c_tblpickctl
			SELECT @n_CountLay4 = COUNT(*) FROM TBLSHPCONF5 (NOLOCK) WHERE ISPCTL = @c_tblpickctl

			SELECT @n_TotCount = (@n_CountLay1 + @n_CountLay2 + @n_CountLay3 + @n_CountLay4)

         UPDATE TBLSHPCONF1
				SET ICRECD = RIGHT('00000' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(CONVERT(NCHAR(5), @n_TotCount))) , 5 )
          WHERE ISPCTL = @c_tblpickctl 
				AND ISPKTN = @c_ExternOrderkey 
      END -- N-CONTINUE
		END -- End checking on existing record.
	END -- End While
END -- End Procedure

GO