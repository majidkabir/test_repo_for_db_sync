SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_CC_vs_System                                           */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 12 Nov 2002  SHONG     1.1   SOS# 8541  Changing Poison Flag from Y to P*/
/* 10-May-2002  YokeBeen  1.2   For ITS Delivery Transaction system        */
/*                               (FBR089)                                  */
/* 18-Feb-2004  YokeBeen  1.3   Changed the Storer ConfigKey from 'OWITF'  */
/*                              to 'ITSITF'                                */
/***************************************************************************/    
CREATE PROC [dbo].[isp_ITSDTran]
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

CREATE TABLE [#Temp_PoiFlag] (
	[LoadKey] [char] (10), 
	[Key3] [char] (20), 
	[TableName] [char] (30),  
	[PoiFlag] [char] (1) ) 

CREATE TABLE [#Temp_ITS] (
	[xEnv] [char] (3), 
	[xCoCode] [char] (3), 
	[xDvCode] [char] (3),  
	[xDocNo] [char] (10),  
	[xDocType] [char] (2),  
	[xInvNo] [char] (10),  
	[xInvDate] [char] (9),  
	[xReceDate] [char] (16),  
	[xEntDate] [char] (16),  
	[xReleDate] [char] (16),  
	[xDlvDate] [char] (9),  
	[xEdlvDate] [char] (9),  
	[xEdlvFlag] [char] (1),  
	[xCbm] [char] (11),  
	[xWeight] [char] (11),  
	[xInstr] [char] (45),  
	[xPoiFlag] [char] (1),  
	[xCustClass] [char] (1),  
	[xDlvGrp] [char] (5),  
	[xTerms] [char] (3),  
	[xCuCode] [char] (8),  
	[xBranch] [char] (3),  
	[xAddrCode] [char] (4),  
	[xCreaSource] [char] (3),  
	[xAmount] [char] (11),  
	[xCurrency] [char] (3),  
	[xScheduleNo] [char] (8),  
	[xVehicleNo] [char] (8) NULL,  
	[xVehicleFlg] [char] (1),  
	[xLoadKey] [char] (10),  
	[xType] [char] (10) NULL, 
	[xTransmitLogKey] [char] (10) ) 

-- First Cursor used to set valid Poison Flag for each record.
-- If anyone of the SKU being found with Poison, the whole Orders will be set to 'Y'
DECLARE CUR1 CURSOR fast_forward read_only FOR

SELECT TRANSMITLOG.Key1, TRANSMITLOG.Key3, TRANSMITLOG.TableName FROM TRANSMITLOG (NOLOCK)
WHERE TRANSMITFLAG = '0'
AND TABLENAME IN ('ITSORD', 'ITSRCPT')

OPEN CUR1

DECLARE @c_Loadkey NVARCHAR(10),
		  @c_Key3 NVARCHAR(20), 
		  @c_TableName NVARCHAR(30), 
		  @c_PoiFlag NVARCHAR(1) 

DECLARE @d_debug NVARCHAR(1)

select @d_debug = '0'

FETCH NEXT FROM CUR1 INTO @c_Loadkey, @c_Key3, @c_TableName 

WHILE @@FETCH_STATUS <> -1
BEGIN

	SELECT @c_PoiFlag = CASE  
		WHEN 
		 ( (SELECT COUNT(DISTINCT SKU.busr8) FROM SKU (nolock), ORDERDETAIL (nolock), 
						TRANSMITLOG (nolock), LOADPLAN (nolock) 
			 WHERE SKU.sku = ORDERDETAIL.sku 
            AND SKU.StorerKey = ORDERDETAIL.StorerKey
				AND ORDERDETAIL.OrderKey = TRANSMITLOG.Key3
				AND LOADPLAN.Loadkey = TRANSMITLOG.Key1
				AND TRANSMITLOG.Key3 = @c_Key3 ) <= 1 AND 
			(SELECT COUNT(DISTINCT SKU.busr8) FROM SKU (nolock), ORDERDETAIL (nolock), 
						TRANSMITLOG (nolock), LOADPLAN (nolock)  
			 WHERE SKU.sku = ORDERDETAIL.sku 
            AND SKU.StorerKey = ORDERDETAIL.StorerKey
				AND ORDERDETAIL.OrderKey = TRANSMITLOG.Key3
				AND LOADPLAN.Loadkey = TRANSMITLOG.Key1
				AND TRANSMITLOG.Key3 = @c_Key3 
				AND SKU.BUSR8 <> '') >= 1 ) THEN 'P'
		WHEN 
		 ( (SELECT COUNT(DISTINCT SKU.busr8) FROM SKU (nolock), ORDERDETAIL (nolock), 
						TRANSMITLOG (nolock), LOADPLAN (nolock)  
			 WHERE SKU.sku = ORDERDETAIL.sku 
            AND SKU.StorerKey = ORDERDETAIL.StorerKey
				AND ORDERDETAIL.OrderKey = TRANSMITLOG.Key3
				AND LOADPLAN.Loadkey = TRANSMITLOG.Key1
				AND TRANSMITLOG.Key3 = @c_Key3 ) <= 1 AND 
			(SELECT COUNT(DISTINCT SKU.busr8) FROM SKU (nolock), ORDERDETAIL (nolock), 
						TRANSMITLOG (nolock), LOADPLAN (nolock)  
			 WHERE SKU.sku = ORDERDETAIL.sku 
            AND SKU.StorerKey = ORDERDETAIL.StorerKey
				AND ORDERDETAIL.OrderKey = TRANSMITLOG.Key3
				AND LOADPLAN.Loadkey = TRANSMITLOG.Key1
				AND TRANSMITLOG.Key3 = @c_Key3 
				AND SKU.BUSR8 <> '') < 1 ) THEN 'N'
		WHEN 
		 ( (SELECT COUNT(DISTINCT SKU.busr8) FROM SKU (nolock), ORDERDETAIL (nolock), 
						TRANSMITLOG (nolock), LOADPLAN (nolock)  
			 WHERE SKU.sku = ORDERDETAIL.sku 
            AND SKU.StorerKey = ORDERDETAIL.StorerKey
				AND ORDERDETAIL.OrderKey = TRANSMITLOG.Key3
				AND LOADPLAN.Loadkey = TRANSMITLOG.Key1
				AND TRANSMITLOG.Key3 = @c_Key3 ) > 1 ) THEN 'P' 
		END   


	INSERT INTO #Temp_PoiFlag ( Loadkey, Key3, TableName, PoiFlag )
	VALUES ( @c_Loadkey, @c_Key3, @c_TableName, @c_PoiFlag )

	IF @d_debug = '1' 
	BEGIN
		Select '#Temp_PoiFlag', @c_Loadkey, @c_Key3, @c_TableName
	END

	FETCH NEXT FROM CUR1 INTO @c_Loadkey, @c_Key3, @c_TableName 
END	
DEALLOCATE CUR1
-- Ended First Cursor.

-- Second Cursor used to retrieve data for ITS Delivery Transaction into #Temp_ITS table.
DECLARE CUR2 CURSOR fast_forward read_only FOR

SELECT LOADKEY, KEY3, TABLENAME, POIFLAG
  FROM #Temp_PoiFlag (NOLOCK)

OPEN CUR2

DECLARE @c_xLoadkey NVARCHAR(10),
		  @c_xKey3 NVARCHAR(20), 
		  @c_xTableName NVARCHAR(30), 
		  @c_xPoiFlag NVARCHAR(1) 

FETCH NEXT FROM CUR2 INTO @c_xLoadkey, @c_xKey3, @c_xTableName, @c_xPoiFlag  

WHILE @@FETCH_STATUS <> -1
BEGIN

	IF @c_xTableName = 'ITSORD' 
	BEGIN -- Begin retrieving ITS data for Shipment Orders.
		INSERT INTO #Temp_ITS (
			xEnv, xCoCode, xDvCode, xDocNo, xDocType, xInvNo, xInvDate, xReceDate, 
			xEntDate, xReleDate, xDlvDate, xEdlvDate, xEdlvFlag, xCbm, xWeight, xInstr, 
			xPoiFlag, xCustClass, xDlvGrp, xTerms, xCuCode, xBranch, xAddrCode, xCreaSource, 
			xAmount, xCurrency, xScheduleNo, xVehicleNo, xVehicleFlg, 
			xLoadKey, xType, xTransmitLogKey ) 
		SELECT	CASE 
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '1') ) THEN 'MER'
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '3') ) THEN 'MER'
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '2') ) THEN 'PER'
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '1') ) THEN 'MWH'
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '3') ) THEN 'MWH'
							WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
									 (SubString(ORDERS.StorerKey , 3, 1) = '2') ) THEN 'PWH'
						END,  
					LEFT(dbo.fnc_LTrim(ORDERS.ExternOrderKey), 3),   
					SubString(dbo.fnc_RTrim(ORDERS.ExternOrderKey), 4, 2) + ' ',   
					CASE WHEN Len(ORDERS.ExternOrderKey) = 0 THEN '          '
								 ELSE CONVERT(NVARCHAR(10), SubString(ORDERS.ExternOrderKey, 6, (Len(ORDERS.ExternOrderKey) - 6) + 1))
						  END,      
					CONVERT(NVARCHAR(2), ORDERS.Type) AS DocType,   
					CASE WHEN Len(ORDERS.ExternOrderKey) = 0 THEN '          '
								 ELSE CONVERT(NVARCHAR(10), SubString(ORDERS.ExternOrderKey, 6, (Len(ORDERS.ExternOrderKey) - 6) + 1))
						  END,      
					CASE ORDERS.DeliveryDate
							WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
							 ' ' + (CONVERT(NVARCHAR(8),	( dbo.fnc_RTrim(CONVERT(CHAR, ORDERS.DeliveryDate , 112))) )) 
						END,     
					CASE ORDERS.AddDate 
							WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
							WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
								CONVERT(NVARCHAR(16),	' '
								 + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), ORDERS.AddDate , 112) ) + ' ' 
								 + ( SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 1, 2) 
								 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 4, 2) 
								 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 7, 2) ) ))) 
						END,   
					CASE ORDERS.AddDate 
							WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
							WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
								CONVERT(NVARCHAR(16),	' ' 
								 + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), ORDERS.AddDate , 112) ) + ' ' 
								 + ( SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 1, 2) 
								 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 4, 2) 
								 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 7, 2) ) ))) 
						END,   
					CONVERT(NVARCHAR(16), '        0      0'),    
					CASE LoadPlan.lpuserdefdate01
							WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
	         			 ' ' + (CONVERT(NVARCHAR(8), LoadPlan.lpuserdefdate01 , 112)) 
						END,   
					CASE ORDERS.DeliveryDate
							WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
							 ' ' + (CONVERT(NVARCHAR(8), ORDERS.DeliveryDate , 112))    
						END,   
				   -- CASE dbo.fnc_RTrim(ORDERS.RDD)
				 	CASE dbo.fnc_RTrim(ORDERS.RDD) 
                    WHEN NULL THEN 'E'
                    WHEN '' THEN 'E' -- #9401 By June
-- Comment by SHONG on 12-MAR-2004
-- SOS# 20586 
--                     WHEN 'E' THEN 'P'
--                     WHEN 'O' THEN 'E'
--                     WHEN 'OE' THEN 'P'
                    ELSE CONVERT(NVARCHAR(1), ISNULL(dbo.fnc_RTrim(ORDERS.Rdd), 'E') )
               END AS EdlvFlag,   
		         CASE ORDERS.Type WHEN 'M' THEN 
								(' ' + (CONVERT(NVARCHAR(10), 
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000.000000', 1, (10 - Len(CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ORDERS.Capacity)))))) ) 
								+ CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ORDERS.Capacity)))) ))) ))) 
		              	ELSE 
								( ' ' + (CONVERT(NVARCHAR(10),
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000.000000', 1, (10 - Len(CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ORDERDETAIL.OpenQty * SKU.STDCUBE)))))) ) 
								+ CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ORDERDETAIL.OpenQty * SKU.STDCUBE)))) ))) )))
				   	END,    
			      CASE ORDERS.Type WHEN 'M' THEN 
								(' ' + (CONVERT(NVARCHAR(10), 
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000000.000', 1, (10 - Len(CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ORDERS.GrossWeight))))) ) 
								+ CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ORDERS.GrossWeight)))) )) ))) 
	                  ELSE 
								(' ' + (CONVERT(NVARCHAR(10), 
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000000.000', 1, (10 - Len(CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ORDERDETAIL.OpenQty * SKU.STDGROSSWGT))))) ) 
								+ CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ORDERDETAIL.OpenQty * SKU.STDGROSSWGT)))) )) )))
				      END,     
		         ISNULL(CONVERT(NVARCHAR(45), ORDERS.Notes2),' ') AS Instr,   
					(SELECT PoiFlag FROM #Temp_PoiFlag (nolock), ORDERS (nolock) 
							WHERE #Temp_PoiFlag.LoadKey = ORDERS.LoadKey
							  AND #Temp_PoiFlag.Key3 = ORDERS.OrderKey
							  AND ORDERS.OrderKey = @c_xKey3),      
					' ',     
		         CONVERT(NVARCHAR(5), ISNULL(ORDERS.Route , '     ') ) AS DlvGrp,   
		         CONVERT(NVARCHAR(3), ISNULL(ORDERS.PmtTerm , '   ') ) AS Terms,   
		         CONVERT(NVARCHAR(8), ISNULL(ORDERS.BillToKey , '        ') ) AS CuCode,   
		  			SubString(ISNULL(ORDERS.ConsigneeKey, '   '), 2, 3),   
		  			SubString(ISNULL(ORDERS.ConsigneeKey, '    ') , 5, 4),   
					'EXE',     
					' ' + (CONVERT(NVARCHAR(10), 
							(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('0000000.00', 1, (10 - Len(CONVERT(CHAR, CONVERT(DECIMAL(9,2), 0)))) )
							+ CONVERT(CHAR, CONVERT(DECIMAL(9,2), 0))) )) )),     
					'   ',      
		         RIGHT(dbo.fnc_RTrim(ISNULL(ORDERS.LoadKey, '        ')), 8),    
					CASE WHEN ( SELECT Count(IDS_LP_VEHICLE.LoadKey)
									  FROM IDS_LP_VEHICLE (NOLOCK) 
											 INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
									 WHERE ( LOADPLAN.LoadKey = ORDERS.LoadKey ) ) > 1
						 -- SOS 9040 wally 20.dec.2002
						 -- added MIN to make sure this subsequery returns 1 row	  
						  THEN (SELECT CONVERT(NVARCHAR(8), ISNULL(MIN(IDS_LP_VEHICLE.VehicleNumber), '        ')) 
									 FROM IDS_LP_VEHICLE (NOLOCK) 
											INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
									WHERE ( LOADPLAN.LoadKey = ORDERS.LoadKey )  
									  AND ( IDS_LP_VEHICLE.LineNumber = '00001' ) )
						  ELSE (SELECT CONVERT(NVARCHAR(8), ISNULL(IDS_LP_VEHICLE.VehicleNumber, '        ')) 
									 FROM IDS_LP_VEHICLE (NOLOCK) 
											INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
									WHERE ( LOADPLAN.LoadKey = ORDERS.LoadKey ) )  
						END,  
					CASE WHEN (SELECT COUNT(IDS_VEHICLE.VehicleNumber)
									 FROM IDS_LP_VEHICLE (NOLOCK) 
										   INNER JOIN IDS_VEHICLE (NOLOCK)  
											   ON ( IDS_LP_VEHICLE.VehicleNumber = IDS_VEHICLE.VehicleNumber )
										   INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
								   WHERE ( LOADPLAN.LoadKey = ORDERS.LoadKey ) ) = 0
							 THEN 'N' 
							 ELSE 'Y' 
						END,    
					ORDERS.LoadKey,   
					ORDERS.Type,   
					TRANSMITLOG.TransmitLogKey  
		    FROM ORDERS (NOLOCK)   
					INNER JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY ) 
					INNER JOIN SKU (NOLOCK) ON ( ORDERDETAIL.STORERKEY = SKU.STORERKEY AND ORDERDETAIL.SKU = SKU.SKU ) 
					INNER JOIN LOADPLAN (NOLOCK) ON ( ORDERS.LOADKEY = LOADPLAN.LOADKEY ) 
					INNER JOIN StorerConfig (NOLOCK) ON ( ORDERS.StorerKey = StorerConfig.StorerKey ) 
					INNER JOIN TRANSMITLOG (NOLOCK) ON ( TRANSMITLOG.Key1 = LOADPLAN.LOADKEY AND TRANSMITLOG.Key3 = ORDERS.ORDERKEY ) 
		   WHERE ( ORDERS.UserDefine08 <> '4' )    
			  AND ( LOADPLAN.FinalizeFlag = 'Y' )
			  AND ( StorerConfig.ConfigKey = 'ITSITF' )  -- (YokeBeen01)
			  AND ( StorerConfig.sValue = '1' )  
			  AND ( TRANSMITLOG.TableName = 'ITSORD' )   
			  AND ( TRANSMITLOG.TransmitFlag = '0' )
			  AND ( ORDERS.OrderKey = @c_xKey3 )    
		GROUP BY CASE 
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '1') ) THEN 'MER'
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '3') ) THEN 'MER'
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) = 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '2') ) THEN 'PER'
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '1') ) THEN 'MWH'
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '3') ) THEN 'MWH'
						WHEN ( (SubString(ORDERS.ExternOrderKey , 6, 2) <> 'SX') AND 
								 (SubString(ORDERS.StorerKey , 3, 1) = '2') ) THEN 'PWH'
						END,  
					LEFT(dbo.fnc_LTrim(ORDERS.ExternOrderKey), 3),   
					SubString(dbo.fnc_RTrim(ORDERS.ExternOrderKey), 4, 2) + ' ',   
					CASE WHEN Len(ORDERS.ExternOrderKey) = 0 THEN '          '
						  ELSE CONVERT(NVARCHAR(10), SubString(ORDERS.ExternOrderKey, 6, (Len(ORDERS.ExternOrderKey) - 6) + 1))
						  END,      
					CONVERT(NVARCHAR(2), ORDERS.Type),   
					CASE WHEN Len(ORDERS.ExternOrderKey) = 0 THEN '          '
						  ELSE CONVERT(NVARCHAR(10), SubString(ORDERS.ExternOrderKey, 6, (Len(ORDERS.ExternOrderKey) - 6) + 1))
						  END,      
					CASE ORDERS.DeliveryDate
						  WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
						  WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
						  ' ' + (CONVERT(NVARCHAR(8),	( dbo.fnc_RTrim(CONVERT(CHAR, ORDERS.DeliveryDate , 112))) ))   
						  END,     
					CASE ORDERS.AddDate 
						  WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
						  WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
						  CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), ORDERS.AddDate , 112) ) + ' ' 
														 + ( SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 1, 2) 
														 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 4, 2) 
														 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 7, 2) ) ) ) )  
						  END,   
					CASE ORDERS.AddDate 
						  WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
						  WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
						  CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), ORDERS.AddDate , 112) ) + ' '  
														 + ( SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 1, 2) 
														 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 4, 2) 
														 +	  SubString(CONVERT(NVARCHAR(8), ORDERS.AddDate , 108), 7, 2) ) ) ) )  
						  END,   
					CASE LoadPlan.lpuserdefdate01
							WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
							' ' + (CONVERT(NVARCHAR(8), LoadPlan.lpuserdefdate01 , 112)) 
							END,   
					CASE ORDERS.DeliveryDate
							WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
							' ' + (CONVERT(NVARCHAR(8), ORDERS.DeliveryDate , 112))
							END,   
			               -- CASE dbo.fnc_RTrim(ORDERS.RDD)
					CASE dbo.fnc_RTrim(ORDERS.RDD) 
                    WHEN NULL THEN 'E'
                    WHEN '' THEN 'E' -- #9401 By June
-- Comment by SHONG on 12-MAR-2004
-- SOS# 20586 
--                     WHEN 'E' THEN 'P'
-- 						  WHEN 'O' THEN 'E'
--                     WHEN  'OE' THEN 'P'
                  ELSE CONVERT(NVARCHAR(1), ISNULL(dbo.fnc_RTrim(ORDERS.Rdd), 'E') )
               END,   
		         ISNULL(CONVERT(NVARCHAR(45), ORDERS.Notes2),' '),   
		         CONVERT(NVARCHAR(5), ISNULL(ORDERS.Route, '     ') ),   
		         CONVERT(NVARCHAR(3), ISNULL(ORDERS.PmtTerm, '   ') ),   
		         CONVERT(NVARCHAR(8), ISNULL(ORDERS.BillToKey, '        ') ),   
		  			SubString(IsNull(ORDERS.ConsigneeKey, '   '), 2, 3),   
		  			SubString(IsNull(ORDERS.ConsigneeKey, '    ') , 5, 4),   
		         RIGHT(dbo.fnc_RTrim(ISNULL(ORDERS.LoadKey, '        ')), 8),    
					ORDERS.LoadKey,   
					ORDERS.Type,   
					TRANSMITLOG.TransmitLogKey   

			IF @d_debug = '1' 
			BEGIN
				Select 'Insert ITSORD', @c_Loadkey, @c_Key3, @c_TableName 
			END
	END -- End retrieving ITS data for Shipment Orders.
	ELSE IF @c_xTableName = 'ITSRCPT' 
		BEGIN -- Begin retrieving ITS data for Trade Return.
			INSERT INTO #Temp_ITS (
				xEnv, xCoCode, xDvCode, xDocNo, xDocType, xInvNo, xInvDate, xReceDate, 
				xEntDate, xReleDate, xDlvDate, xEdlvDate, xEdlvFlag, xCbm, xWeight, xInstr, 
				xPoiFlag, xCustClass, xDlvGrp, xTerms, xCuCode, xBranch, xAddrCode, xCreaSource, 
				xAmount, xCurrency, xScheduleNo, xVehicleNo, xVehicleFlg, 
				xLoadKey, xType, xTransmitLogKey ) 
			SELECT	CASE 
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '1') ) THEN 'MER'
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '3') ) THEN 'MER'
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '2') ) THEN 'PER'
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '1') ) THEN 'MER'
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '3') ) THEN 'MER'
								WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
										 (SubString(RECEIPT.StorerKey , 3, 1) = '2') ) THEN 'PER'
							END,  
						LEFT(dbo.fnc_LTrim(RECEIPT.ExternReceiptKey), 3),   
						SubString(dbo.fnc_RTrim(RECEIPT.ExternReceiptKey), 4, 2) + ' ',   
						CASE WHEN Len(RECEIPT.ExternReceiptKey) = 0 THEN '          '
								 ELSE CONVERT(NVARCHAR(10), SubString(RECEIPT.ExternReceiptKey, 6, (Len(RECEIPT.ExternReceiptKey) - 6) + 1))
							END,      
						CONVERT(NVARCHAR(2), '3 '),   
						CASE WHEN Len(RECEIPT.ExternReceiptKey) = 0 THEN '          '
								 ELSE CONVERT(NVARCHAR(10), SubString(RECEIPT.ExternReceiptKey, 6, (Len(RECEIPT.ExternReceiptKey) - 6) + 1))
							END,      
						CASE RECEIPT.EffectiveDate
								WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
								WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
								 ' ' + (CONVERT(NVARCHAR(8),	( dbo.fnc_RTrim(CONVERT(CHAR, RECEIPT.EffectiveDate , 112))) ))   
							END,     
						CASE RECEIPT.AddDate 
								WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
								WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
								CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 112) ) + ' ' 
									 + ( SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 1, 2) 
									 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 4, 2) 
									 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 7, 2) ) ))) 
							END,   
						CASE RECEIPT.AddDate 
								WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
								WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
								CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 112) ) + ' '  
									 + ( SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 1, 2) 
									 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 4, 2) 
									 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 7, 2) ) ))) 
							END,   
						CONVERT(NVARCHAR(16), '        0      0'),    
						CASE LoadPlan.lpuserdefdate01 
								WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
								WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
								 ' ' + (CONVERT(NVARCHAR(8), LoadPlan.lpuserdefdate01 , 112)) 
							END,   
						CASE RECEIPT.EffectiveDate 
								WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
								WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
								 ' ' + (CONVERT(NVARCHAR(8), RECEIPT.EffectiveDate , 112)) 
							END,   
			         ' ',   
			         (' ' + (CONVERT(NVARCHAR(10),
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000.000000', 1, (10 - Len(CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ReceiptDETAIL.QtyExpected * SKU.STDCUBE)))))) ) 
								+ CONVERT(CHAR, (SUM(CONVERT(DECIMAL(9,6), ReceiptDETAIL.QtyExpected * SKU.STDCUBE)))) ))) ))), 
				      (' ' + (CONVERT(NVARCHAR(10), 
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('000000.000', 1, (10 - Len(CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ReceiptDETAIL.QtyExpected * SKU.STDGROSSWGT))))) ) 
								+ CONVERT(CHAR, SUM(CONVERT(DECIMAL(9,3), ReceiptDETAIL.QtyExpected * SKU.STDGROSSWGT)))) )) ))), 
			         ISNULL(CONVERT(NVARCHAR(45), RECEIPT.Notes),' ') AS Instr,   
						(SELECT PoiFlag FROM #Temp_PoiFlag (nolock), RECEIPT (nolock) 
								WHERE #Temp_PoiFlag.LoadKey = RECEIPT.LoadKey
								  AND #Temp_PoiFlag.Key3 = RECEIPT.ReceiptKey
								  AND RECEIPT.ReceiptKey = @c_xKey3),      
						' ',     
			         CONVERT(NVARCHAR(5), ISNULL(LOADPLAN.Route , '     ') ) AS DlvGrp,   
			         '   ',   
			         '        ',   
			  			'   ',   
			  			'    ',   
						'EXE',     
						' ' + (CONVERT(NVARCHAR(10), 
								(dbo.fnc_RTrim(dbo.fnc_LTrim(SubString('0000000.00', 1, (10 - Len(CONVERT(CHAR, CONVERT(DECIMAL(9,2), 0)))) )
								+ CONVERT(CHAR, CONVERT(DECIMAL(9,2), 1))) )) )),     
						'   ',      
			         RIGHT(dbo.fnc_RTrim(ISNULL(RECEIPT.LoadKey, '        ')), 8),    
						CASE WHEN ( SELECT Count(IDS_LP_VEHICLE.LoadKey)
										  FROM IDS_LP_VEHICLE (NOLOCK) 
												 INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
										 WHERE ( LOADPLAN.LoadKey = RECEIPT.LoadKey ) ) > 1 
                       -- SOS 13607 wally 18.aug.03
						     -- added MIN to make sure this subsequery returns 1 row	   
							  THEN (SELECT CONVERT(NVARCHAR(8), ISNULL(MIN(IDS_LP_VEHICLE.VehicleNumber), '        ')) 
										 FROM IDS_LP_VEHICLE (NOLOCK) 
												INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
										WHERE ( LOADPLAN.LoadKey = RECEIPT.LoadKey )  
										  AND ( IDS_LP_VEHICLE.LineNumber = '00001' ) )
							  ELSE (SELECT CONVERT(NVARCHAR(8), ISNULL(IDS_LP_VEHICLE.VehicleNumber, '        ')) 
										 FROM IDS_LP_VEHICLE (NOLOCK) 
												INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
										WHERE ( LOADPLAN.LoadKey = RECEIPT.LoadKey ) )  
							END,  
						CASE WHEN (SELECT COUNT(IDS_VEHICLE.VehicleNumber)
										FROM IDS_LP_VEHICLE (NOLOCK) 
											  INNER JOIN IDS_VEHICLE (NOLOCK)  
												  ON ( IDS_LP_VEHICLE.VehicleNumber = IDS_VEHICLE.VehicleNumber )
											  INNER JOIN LOADPLAN (NOLOCK) ON ( IDS_LP_VEHICLE.LoadKey = LOADPLAN.LoadKey ) 
									  WHERE ( LOADPLAN.LoadKey = RECEIPT.LoadKey )  
									  		 ) = 0
							 THEN 'N' 
							 ELSE 'Y' 
							END,    
						RECEIPT.LoadKey,   
						'',   
						TRANSMITLOG.TransmitLogKey   
			    FROM RECEIPT (NOLOCK)   
						INNER JOIN RECEIPTDETAIL (NOLOCK) ON ( RECEIPT.ReceiptKEY = RECEIPTDETAIL.ReceiptKEY ) 
						INNER JOIN SKU (NOLOCK) ON ( RECEIPTDETAIL.STORERKEY = SKU.STORERKEY AND RECEIPTDETAIL.SKU = SKU.SKU ) 
						INNER JOIN LOADPLAN (NOLOCK) ON ( RECEIPT.LOADKEY = LOADPLAN.LOADKEY ) 
						INNER JOIN StorerConfig (NOLOCK) ON ( RECEIPT.StorerKey = StorerConfig.StorerKey ) 
						INNER JOIN TRANSMITLOG (NOLOCK) ON ( TRANSMITLOG.Key1 = LOADPLAN.LOADKEY AND TRANSMITLOG.Key3 = RECEIPT.ReceiptKEY ) 
			   WHERE ( LOADPLAN.FinalizeFlag = 'Y' )
				  AND ( StorerConfig.ConfigKey = 'ITSITF' )  -- (YokeBeen01)
				  AND ( StorerConfig.sValue = '1' )  
				  AND ( TRANSMITLOG.TableName = 'ITSRCPT' )   
				  AND ( TRANSMITLOG.TransmitFlag = '0' )
				  AND ( RECEIPT.ReceiptKey = @c_xKey3 )    
			GROUP BY CASE 
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '1') ) THEN 'MER'
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '3') ) THEN 'MER'
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) = 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '2') ) THEN 'PER'
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '1') ) THEN 'MER'
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '3') ) THEN 'MER'
							WHEN ( (SubString(RECEIPT.ExternReceiptKey , 6, 2) <> 'SX') AND 
									 (SubString(RECEIPT.StorerKey , 3, 1) = '2') ) THEN 'PER'
							END,  
						LEFT(dbo.fnc_LTrim(RECEIPT.ExternReceiptKey), 3),   
						SubString(dbo.fnc_RTrim(RECEIPT.ExternReceiptKey), 4, 2) + ' ',   
						CASE WHEN Len(RECEIPT.ExternReceiptKey) = 0 THEN '          '
							  ELSE CONVERT(NVARCHAR(10), SubString(RECEIPT.ExternReceiptKey, 6, (Len(RECEIPT.ExternReceiptKey) - 6) + 1))
							  END,      
						CASE WHEN Len(RECEIPT.ExternReceiptKey) = 0 THEN '          '
							  ELSE CONVERT(NVARCHAR(10), SubString(RECEIPT.ExternReceiptKey, 6, (Len(RECEIPT.ExternReceiptKey) - 6) + 1))
							  END,      
						CASE RECEIPT.EffectiveDate
							  WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
							  WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
							  ' ' + (CONVERT(NVARCHAR(8),	( dbo.fnc_RTrim(CONVERT(CHAR, RECEIPT.EffectiveDate , 112))) ))  
							  END,     
						CASE RECEIPT.AddDate 
							  WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
							  WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
							  CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 112) ) + ' ' 
															 + ( SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 1, 2) 
															 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 4, 2) 
															 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 7, 2) ) ) ) )
							  END,   
						CASE RECEIPT.AddDate 
							  WHEN ('') THEN CONVERT(NVARCHAR(16), '        0      0') 
							  WHEN NULL THEN CONVERT(NVARCHAR(16), '        0      0') ELSE 
							  CONVERT(NVARCHAR(16),	' ' + ( dbo.fnc_RTrim( dbo.fnc_RTrim(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 112) ) + ' ' 
															 + ( SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 1, 2) 
															 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 4, 2) 
															 +	  SubString(CONVERT(NVARCHAR(8), RECEIPT.AddDate , 108), 7, 2) ) ) ) )  
							  END,   
						CASE LoadPlan.lpuserdefdate01 
								WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
								WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
								' ' + (CONVERT(NVARCHAR(8), LoadPlan.lpuserdefdate01 , 112)) 
								END,   
						CASE RECEIPT.EffectiveDate 
								WHEN ('') THEN CONVERT(NVARCHAR(9), '        0') 
								WHEN NULL THEN CONVERT(NVARCHAR(9), '        0') ELSE 
								' ' + (CONVERT(NVARCHAR(8), RECEIPT.EffectiveDate , 112)) 
								END,   
			         ISNULL(CONVERT(NVARCHAR(45), RECEIPT.Notes),' '),   
			         CONVERT(NVARCHAR(5), ISNULL(LOADPLAN.Route, '     ') ),   
			         RIGHT(dbo.fnc_RTrim(ISNULL(RECEIPT.LoadKey, '        ')), 8),    
						RECEIPT.LoadKey,   
						TRANSMITLOG.TransmitLogKey   

			IF @d_debug = '1' 
			BEGIN
				Select 'Insert ITSRCPT', @c_Loadkey, @c_Key3, @c_TableName 
			END
		END -- End retrieving ITS data for Trade Returen.

	FETCH NEXT FROM CUR2 INTO @c_xLoadkey, @c_xKey3, @c_xTableName, @c_xPoiFlag 
END	
DEALLOCATE CUR2
-- Ended Second Cursor.

-- Retrieve overall data for ITS Upload.
SELECT Env = xEnv,					CoCode = xCoCode,				DvCode = xDvCode, 
		 DocNo = xDocNo, 				DocType = xDocType,			InvNo = xInvNo, 
		 InvDate = xInvDate,			ReceDate = xReceDate,		EntDate = xEntDate, 
		 ReleDate = xReleDate,		DlvDate = xDlvDate,			EdlvDate = xEdlvDate, 
		 EdlvFlag = xEdlvFlag,		Cbm = xCbm,						Weight = xWeight,
		 Instr = xInstr,				PoiFlag = xPoiFlag,			CustClass = xCustClass,	
		 DlvGrp = xDlvGrp,			Terms = xTerms,				CuCode = xCuCode, 
		 Branch = xBranch,			AddrCode = xAddrCode,		CreaSource = xCreaSource, 
		 Amount = xAmount,			Currency = xCurrency,		ScheduleNo = xScheduleNo, 
		 VehicleNo = xVehicleNo,	VehicleFlg = xVehicleFlg, 
		 xLoadKey,						xType,							xTransmitLogKey  
  FROM  #Temp_ITS  
-- End Retrieve.

DROP TABLE #Temp_PoiFlag
DROP TABLE #Temp_ITS

END -- End Procedure

GO