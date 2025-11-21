SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispReddWerkWaveValidation                          */  
/* Creation Date: 2012-05-02                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Do not allow to Release Wave if this validation failed      */
/*          To prevent file reject from WCS                             */  
/*                                                                      */ 
/* Input Parameters:  @c_Wavekey  - (Wave #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: ispWAVRL01                                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2012-05-02   Shong    1.0  Added ReddWerk Validation                 */ 
/* 2012-07-04   Shong    1.1  Added Validation Error Log    SOS#249067  */
/* 2012-07-26   ChewKP   1.2  SOS#251460 - Validate against location    */
/*                            cannot have multiple packsize (ChewKP01)  */
/************************************************************************/  
CREATE PROC  [dbo].[ispReddWerkWaveValidation] 
   @c_WaveKey  NVARCHAR(10), 
   @b_Success  INT OUTPUT, 
   @n_err      INT OUTPUT, 
   @c_ErrMsg   NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON

   SET @c_ErrMsg = ''
   SET @n_err = 0
   SET @b_Success = 1

 DECLARE   @n_BlankLoadKey             INT
          ,@b_BlankStorerKey           INT
          ,@b_BlankFacility            INT
          ,@b_BlankPriority            INT
          ,@b_BlankExternConsoOrderKey INT 
          ,@b_BlankConsoOrderKey       INT
          ,@b_BlankOrderType           INT
          ,@b_BlankBuyerPO             INT
          ,@b_BlankCustomerID          INT
          ,@b_BlankConsigneeKey        INT
          ,@b_BlankMarkForKey          INT
          ,@b_BlankRetail              INT
          ,@c_Loc                      NVARCHAR(10)  -- (CheWKP01)
          ,@c_SKU                      NVARCHAR(20)  -- (CheWKP01)
          ,@c_StorerKey                NVARCHAR(15)  -- (CheWKP01)
          ,@nPackSize                  INT       -- (CheWKP01)
          ,@nNoOfPackSize              INT       -- (ChewKP01)
          
             
   IF OBJECT_ID('tempdb..#WaveHeader') IS NOT NULL
      DROP TABLE #WaveHeader
      
   SELECT ISNULL(RTRIM(OD.ConsoOrderKey) ,'') [ConsoOrderKey] 
   ,ISNULL(RTRIM(OH.LoadKey) ,'')       [LoadKey] 
   ,ISNULL(RTRIM(OH.StorerKey) ,'')     [StorerKey] 
   ,ISNULL(RTRIM(OH.Facility) ,'')      [Facility] 
   ,MAX(ISNULL(RTRIM(OH.Priority) ,'')) [Priority] 
   ,ISNULL(RTRIM(OD.ExternConsoOrderKey) ,'') [ExternConsoOrderKey] 
   ,MAX(ISNULL(RTRIM(OH.Type) ,''))         [OrderType] 
   ,MAX(ISNULL(RTRIM(OH.BuyerPO) ,''))      [BuyerPO] 
   ,ISNULL(RTRIM(OH.IntermodalVehicle) ,'') [CustomerID] 
   ,ISNULL(RTRIM(OH.ConsigneeKey) ,'')      [ConsigneeKey] 
   ,ISNULL(RTRIM(OH.MarkforKey) ,'')        [MarkforKey] 
   ,MAX(ISNULL(RTRIM(OH.M_Phone2) ,''))     [ServiceLevel] 
   ,MAX(CASE SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,8 ,1) 
         WHEN 'Y' THEN 'Y'  
         ELSE 'N'  
    END) AS [MasterPack]  
   ,MAX(CASE 
         WHEN DATEDIFF(DAY, GETDATE(), OH.OrderDate) > 0 THEN 'N' 
         WHEN SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,10 ,1) = 'Y' THEN 'N'    -- New Store
         WHEN SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,12 ,1) = 'Y' THEN 'N'    -- Export flag
         WHEN (CASE SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,11 ,1) WHEN 'Y' THEN 'Y'  --Split Shipment  
               ELSE 'N' END) = 'Y' THEN 'Y' 
         ELSE 'N'  
       END) AS [Fluid] 
   ,MAX(CASE SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,11 ,1)  
         WHEN 'Y' THEN 'Y'  
         ELSE 'N'  
    END) AS [Split]  
   ,MAX(CASE WHEN SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,9 ,1) = 'N' THEN 'N' ELSE 'Y' END) AS [PackList]  
   ,MAX(ISNULL(RTRIM(CASE WHEN OH.Door = 'ECOM' THEN 'RETL' ELSE OH.Door END) ,'')) AS [Retail]  
   ,MAX(SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,7 ,1))  AS [GOH]  
   ,MAX(SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,6 ,1))  AS [PackCode]  
   ,MAX(ISNULL(RTRIM(OH.Stop) ,'')) AS [SpecialHandling]  
   ,MAX(CASE SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,12 ,1)  
    WHEN 'N' THEN '' 
          WHEN 'Y' THEN ISNULL(OI.OrderInfo07,'')  
          ELSE ''  
         END) AS [ExportOrder]  
    ,MAX(SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,10 ,1)) AS [NewStore]  
    ,MAX(ISNULL(RTRIM(OH.B_Phone2) ,'')) AS [EventCode]  
    ,MAX(ISNULL(RTRIM(OH.M_Fax1) ,''))   AS [Parcel Account Number]   
    ,MAX(ISNULL(RTRIM(OH.M_State) ,'')) AS [M_State] 
    INTO #WaveHeader   
    FROM dbo.WAVE WV WITH (NOLOCK) 
    JOIN dbo.WAVEDETAIL WD WITH (NOLOCK)  
    ON WV.WaveKey = WD.WaveKey 
    JOIN dbo.ORDERS OH WITH (NOLOCK)    
    ON WD.OrderKey = OH.OrderKey     
    JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey 
    LEFT OUTER JOIN dbo.ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey = OH.OrderKey  										 
    WHERE WV.WaveKey = @c_WaveKey     
    GROUP BY 
          ISNULL(RTRIM(OD.ConsoOrderKey) ,'')  
         ,ISNULL(RTRIM(OH.LoadKey) ,'')     
         ,ISNULL(RTRIM(OH.StorerKey) ,'')       
         ,ISNULL(RTRIM(OH.Facility) ,'')       
         ,ISNULL(RTRIM(OD.ExternConsoOrderKey) ,'')   
         ,ISNULL(RTRIM(OH.IntermodalVehicle) ,'') 
         ,ISNULL(RTRIM(OH.ConsigneeKey) ,'')    
         ,ISNULL(RTRIM(OH.MarkforKey) ,'')            
   ORDER BY ISNULL(RTRIM(OD.ConsoOrderKey),'') 


   SELECT  @n_BlankLoadKey = SUM(CASE WHEN LoadKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankStorerKey = SUM(CASE WHEN StorerKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankFacility = SUM(CASE WHEN Facility = '' THEN 1 ELSE 0 END) 
          ,@b_BlankPriority = SUM(CASE WHEN Priority = '' THEN 1 ELSE 0 END) 
          ,@b_BlankExternConsoOrderKey = SUM(CASE WHEN ExternConsoOrderKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankConsoOrderKey = SUM(CASE WHEN ConsoOrderKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankOrderType = SUM(CASE WHEN OrderType = '' THEN 1 ELSE 0 END) 
          ,@b_BlankBuyerPO = SUM(CASE WHEN BuyerPO = '' THEN 1 ELSE 0 END) 
          ,@b_BlankCustomerID = SUM(CASE WHEN CustomerID = '' THEN 1 ELSE 0 END) 
          ,@b_BlankConsigneeKey = SUM(CASE WHEN ConsigneeKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankMarkForKey = SUM(CASE WHEN MarkForKey = '' THEN 1 ELSE 0 END) 
          ,@b_BlankRetail = SUM(CASE WHEN Retail = '' THEN 1 ELSE 0 END) 
   FROM #WaveHeader  


   IF EXISTS(SELECT 1 FROM #WaveHeader WHERE [Retail] NOT IN ('RETL','WHOL','ECOM'))
   BEGIN
   	SET @b_Success = 0
   	SET @n_err = 75100
   	SET @c_ErrMsg = 'Customer type must be of known type: RETL, WHOL, ECOM'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Title: Customer type must be of known type: RETL, WHOL, ECOM!')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'Buyer PO') + ' '      
                                 + CONVERT(NVARCHAR(40), 'Retail') )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 20) + ' '   
                                 + CONVERT(NVARCHAR(40), REPLICATE('-', 40)) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT @c_WaveKey,  
             CONVERT(NVARCHAR(20), [BuyerPO] ) + ' ' +       
             CONVERT(NVARCHAR(40), [Retail]) + ' '   
      FROM #WaveHeader WITH (NOLOCK)  
          WHERE [Retail] NOT IN ('RETL','WHOL','ECOM') 
      ORDER BY BuyerPO, [Retail]  

   	--GOTO QUIT_SP
   END
   
   IF EXISTS(SELECT 1 FROM #WaveHeader WHERE PackCode NOT IN ('X', 'S', 'D', 'U'))
   BEGIN
   	SET @b_Success = 0
   	SET @n_err = 75101
   	SET @c_ErrMsg = 'Pack Code Must Be X,S,D or U (B_Fax1,6,1)'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Pack Code Must Be X,S,D or U (B_Fax1,6,1)')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'Buyer PO') + ' '      
                                 + CONVERT(NVARCHAR(20), 'Pack Code') )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 20) + ' '   
                                 + CONVERT(NVARCHAR(40), REPLICATE('-', 20)) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT @c_WaveKey,  
             CONVERT(NVARCHAR(20), [BuyerPO] ) + ' ' +       
             CONVERT(NVARCHAR(40), PackCode) + ' '   
      FROM #WaveHeader WITH (NOLOCK)  
      WHERE PackCode NOT IN ('X', 'S', 'D', 'U')
      ORDER BY OrderKey, [Retail]  

   	--GOTO QUIT_SP
   END

   DECLARE @cCheckLOC NVARCHAR(10),
           @cCheckSKU NVARCHAR(20)
           
   IF OBJECT_ID('tempdb..#WaveDetail') IS NOT NULL
      DROP TABLE #WaveDetail

   SELECT OD.ConsoOrderKey
      ,ISNULL(RTRIM(OD.ConsoOrderLineNo),'') AS ConsoOrderLineNo
      ,ISNULL(RTRIM(OD.OrderLineNumber),'')  AS OrderLineNumber
      ,ISNULL(RTRIM(OD.OrderKey),'')         AS OrderKey
      ,ISNULL(RTRIM(OD.Sku),'')              AS Sku
      ,ISNULL(RTRIM(OD.AltSku),'')           AS AltSku
      ,ISNULL(RTRIM(OD.Lottable01),'')       AS Lottable01
      ,ISNULL(RTRIM(OD.Lottable02),'')       AS Lottable02
      ,ISNULL(RTRIM(OD.Lottable03),'')       AS Lottable03 
      ,ISNULL(RTRIM(OD.ID),'')               AS ID 
      ,ISNULL(RTRIM(CLK.Short),'R')          AS LocType 
      ,CASE WHEN ISNULL(RTRIM(LOC.LogicalLocation),'') = '' 
              OR ISNUMERIC(LOC.LogicalLocation) <> 1 
            THEN '99999' ELSE ISNULL(RTRIM(LOC.LogicalLocation),'') 
       END AS LogicalLoc  
      ,CASE WHEN LOC.LocationCategory IN ('SHELVING','GOH') 
            THEN 1 
            ELSE dbo.fnc_GetLocUccPackSize(PD.StorerKey, PD.SKU, PD.LOC) 
       END AS PackQty 
      ,ISNULL(SKU.STDCUBE,0)        AS StdCube 
      ,ISNULL(SKU.STDGROSSWGT,0)    AS StdGrossWgt 
      ,ISNULL(RTRIM(SKU.Style),'')  AS Style
      ,ISNULL(RTRIM(SKU.Color),'')  AS Color 
      ,ISNULL(RTRIM(SKU.Size),'')   AS [SIZE] 
      ,ISNULL(RTRIM(SKU.Measurement),'') AS Measurement 
      ,ISNULL(RTRIM(SKU.DESCR),'') AS SKUDescr 
      ,ISNULL(RTRIM(SKU.SUSR1),'') AS Division 
      ,ISNULL(RTRIM(SKU.SUSR5),'') AS SUSR5
      ,ISNULL(RTRIM(SKU.CLASS),'') AS BusinessGroup  
      ,CASE ISNULL(RTRIM(SKU.ItemClass),'') 
          WHEN 'NONCON' THEN 'N' 
          ELSE 'Y' 
       END AS Conveyable 
      ,CASE ISNULL(RTRIM(SKU.ItemClass),'') 
          WHEN 'GOH' THEN 'Y' 
          ELSE 'N' 
       END AS GOH  
      ,ISNULL(RTRIM(PD.LOC),'') AS LOC 
      ,ISNULL(SUM(PD.Qty),0) AS Qty
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Length,0)) AS [Length]
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Width,0))  AS Width
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Height,0)) AS Height
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.LengthUOM1,0)) AS LengthUOM1 
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.WidthUOM1,0))  AS WidthUOM1
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.HeightUOM1,0)) AS HeightUOM1
      ,ISNULL(RTRIM(SKU.SKUGroup),'')	AS SKUGroup
   INTO #WaveDetail 
    FROM dbo.ORDERS OH WITH (NOLOCK) 
    JOIN dbo.ORDERDETAIL OD WITH (NOLOCK)
       ON (OH.StorerKey = OD.StorerKey AND OH.OrderKey = OD.OrderKey) 
    JOIN dbo.SKU SKU WITH (NOLOCK)  ON (OD.StorerKey = SKU.StorerKey AND OD.SKU = SKU.SKU) 
    JOIN dbo.PACK PACK WITH (NOLOCK)  ON SKU.PackKey = PACK.PackKey 
    JOIN dbo.PICKDETAIL PD WITH (NOLOCK)  ON (OD.StorerKey = PD.StorerKey AND OD.OrderKey = PD.OrderKey
         AND OD.OrderLineNumber = PD.OrderLineNumber)
    JOIN dbo.LOC LOC WITH (NOLOCK)  ON PD.LOC = LOC.LOC
    LEFT JOIN dbo.CODELKUP CLK WITH (NOLOCK)  ON (CLK.ListName = 'LOCCATEGRY' AND LOC.LocationCategory = CLK.Code)
   WHERE OH.UserDefine09 = @c_WaveKey 
   GROUP BY 
       OD.ConsoOrderKey
      ,ISNULL(RTRIM(OD.ConsoOrderLineNo),'') 
      ,ISNULL(RTRIM(OD.OrderLineNumber),'')  
      ,ISNULL(RTRIM(OD.OrderKey),'')         
      ,ISNULL(RTRIM(OD.Sku),'')              
      ,ISNULL(RTRIM(OD.AltSku),'')           
      ,ISNULL(RTRIM(OD.Lottable01),'')       
      ,ISNULL(RTRIM(OD.Lottable02),'')       
      ,ISNULL(RTRIM(OD.Lottable03),'')        
      ,ISNULL(RTRIM(OD.ID),'')                
      ,ISNULL(RTRIM(CLK.Short),'R')           
      ,CASE WHEN ISNULL(RTRIM(LOC.LogicalLocation),'') = '' 
              OR ISNUMERIC(LOC.LogicalLocation) <> 1 
            THEN '99999' ELSE ISNULL(RTRIM(LOC.LogicalLocation),'') 
       END   
      ,CASE WHEN LOC.LocationCategory IN ('SHELVING','GOH') 
            THEN 1 
            ELSE dbo.fnc_GetLocUccPackSize(PD.StorerKey, PD.SKU, PD.LOC) 
       END  
      ,ISNULL(SKU.STDCUBE,0)         
      ,ISNULL(SKU.STDGROSSWGT,0)     
      ,ISNULL(RTRIM(SKU.Style),'')  
      ,ISNULL(RTRIM(SKU.Color),'')   
      ,ISNULL(RTRIM(SKU.Size),'')    
      ,ISNULL(RTRIM(SKU.Measurement),'')  
      ,ISNULL(RTRIM(SKU.DESCR),'')  
      ,ISNULL(RTRIM(SKU.SUSR1),'')  
      ,ISNULL(RTRIM(SKU.SUSR5),'') 
      ,ISNULL(RTRIM(SKU.CLASS),'')  
      ,CASE ISNULL(RTRIM(SKU.ItemClass),'') 
          WHEN 'NONCON' THEN 'N' 
          ELSE 'Y' 
       END  
      ,CASE ISNULL(RTRIM(SKU.ItemClass),'') 
          WHEN 'GOH' THEN 'Y' 
          ELSE 'N' 
       END   
      ,ISNULL(RTRIM(PD.LOC),'')  
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Length,0)) 
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Width,0))  
      ,CONVERT(DECIMAL(10,2),ISNULL(SKU.Height,0)) 
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.LengthUOM1,0))  
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.WidthUOM1,0))  
      ,CONVERT(DECIMAL(10,2),ISNULL(PACK.HeightUOM1,0)) 
      ,ISNULL(RTRIM(SKU.SKUGroup),'')	
   ORDER BY 1, 2 

   IF EXISTS(SELECT ConsoOrderKey, ConsoOrderLineNo, SKU, LOC
             FROM #WaveDetail 
             GROUP BY ConsoOrderKey, ConsoOrderLineNo, SKU, LOC
             HAVING COUNT(*) > 1)               
   BEGIN
   	 SET @b_Success = 0
	   SET @n_err = 75102
	   SET @c_ErrMsg = 'Found Duplicate Conso Order Line, SKU, LOC'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found Duplicate Conso Order Line, SKU, LOC')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'ConsoOrderKey') + ' '      
                                 + CONVERT(NVARCHAR(20), 'ConsoOrderLineNo') + ' ' +
                                 + CONVERT(NVARCHAR(20), 'SKU') + ' ' + 
                                 + CONVERT(NVARCHAR(20), 'Location')    )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 20) + ' '   
                                 + CONVERT(NVARCHAR(20), REPLICATE('-', 20)) + ' ' 
                                 + CONVERT(NVARCHAR(20), REPLICATE('-', 20)) + ' '
                                 + CONVERT(NVARCHAR(20), REPLICATE('-', 20)) + ' ')         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT @c_WaveKey,  
         CONVERT(NVARCHAR(20), ConsoOrderKey) + ' ' + 
         CONVERT(NVARCHAR(20), ConsoOrderLineNo) + ' ' +  
         CONVERT(NVARCHAR(20), SKU) + ' ' + 
         CONVERT(NVARCHAR(20), LOC) 
      FROM #WaveDetail 
      GROUP BY ConsoOrderKey, ConsoOrderLineNo, SKU, LOC
      HAVING COUNT(*) > 1

	   --GOTO QUIT_SP
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE LocType NOT IN ('S','R'))
   BEGIN
   	SET @b_Success = 0
	   SET @n_err = 75104
	   SET @c_ErrMsg = 'Location Type Must Be S OR R'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Location Type Must Be S OR R')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'LOC') + ' '      
                                 + CONVERT(NVARCHAR(10), 'Type') )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 10) + ' '   
                                 + CONVERT(NVARCHAR(10), REPLICATE('-', 10)) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT @c_WaveKey,  
         CONVERT(NVARCHAR(10), LOC) + ' ' + 
         CONVERT(NVARCHAR(10), LocType) 
      FROM #WaveDetail 
      WHERE LocType NOT IN ('S','R')
      GROUP BY LOC, LocType 

	   --GOTO QUIT_SP 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE Lottable02 = '')
   BEGIN
   	SET @b_Success = 0
	   SET @n_err = 75105
	   SET @c_ErrMsg = 'Found Blank LOT (Lottable02)'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found Blank LOT (Lottable02)')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'Order#') + ' '      
                                 + CONVERT(NVARCHAR(10), 'LOC') + ' '  +
                                 + CONVERT(NVARCHAR(20), 'SKU') + ' '  +
                                 + CONVERT(NVARCHAR(10), 'Qty') + ' '  +
                                 + CONVERT(NVARCHAR(20), 'Lottable02')  )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 20) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT @c_WaveKey,  
         CONVERT(NVARCHAR(10), OrderKey) + ' ' +
         CONVERT(NVARCHAR(10), LOC) + ' ' + 
         CONVERT(NVARCHAR(20), SKU) + ' ' +
         CONVERT(NVARCHAR(10), Qty) + ' ' +
         CONVERT(NVARCHAR(20), Lottable02) 
      FROM #WaveDetail 
      WHERE Lottable02 = ''

	   --GOTO QUIT_SP 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE PackQty = 0)
   BEGIN
      SET @c_ErrMsg = ''
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '      No UCC Qty Found')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'Location') + ' '      
                                 + CONVERT(NVARCHAR(20), 'SKU') )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 20) )         

	   DECLARE CUR_ZeroPack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	   SELECT DISTINCT LOC, SKU  
	   FROM #WaveDetail 
	   WHERE PackQty = 0
   	
	   OPEN CUR_ZeroPack 
   	
	   FETCH NEXT FROM CUR_ZeroPack INTO @cCheckLOC, @cCheckSKU
	   WHILE @@FETCH_STATUS <> -1  
	   BEGIN
	   	SET @b_Success = 0
	   	SET @n_err = 75110
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 
	                     'LOC: ' + RTRIM(@cCheckLOC) + ' SKU: ' + 
                        RTRIM(@cCheckSKU) + ' With ZERO UCC Qty' + CHAR(13) 

         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES 
         (@c_WaveKey, CONVERT(NVARCHAR(10), @cCheckLOC) + ' ' +  CONVERT(NVARCHAR(20), @cCheckSKU))  
   	   	
		   FETCH NEXT FROM CUR_ZeroPack INTO @cCheckLOC, @cCheckSKU 
	   END
	   CLOSE CUR_ZeroPack 
	   DEALLOCATE CUR_ZeroPack 
   END
   

   -- (ChewKP01)
   SET @nNoOfPackSize = 0 
   
   DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   
   SELECT DISTINCT WD.Loc, WD.SKU, O.StorerKey
   FROM #WaveDetail WD WITH (NOLOCK)
   INNER JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
   JOIN LOC LOC WITH (NOLOCK) ON Loc.Loc = WD.Loc
   WHERE Loc.LocationCategory NOT IN ('SHELVING','GOH') 
   
   
   OPEN CUR_UCC      
         
   FETCH NEXT FROM CUR_UCC INTO @c_Loc, @c_SKU, @c_StorerKey 
   WHILE @@FETCH_STATUS <> -1      
   BEGIN    
   	
      SELECT @nNoOfPackSize = COUNT(DISTINCT UCC.Qty) 
   	FROM   UCC WITH (NOLOCK) 
   	WHERE  UCC.StorerKey = @c_StorerKey 
   	AND    UCC.SKU = @c_SKU 
   	AND    UCC.LOC = @c_Loc 
   	AND    UCC.[STATUS] < '6' 
   	
      
      IF @nNoOfPackSize > 1 
      BEGIN
         
         SET @b_Success = 0 
         SET @n_err = 75113
         SET @c_ErrMsg = 'Found UCC in Location with Multiple Pack Size'
         
         
         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')       
         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found UCC in Location with Multiple Pack Size')    
         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')    
         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'Loc') + ' '    
                               + CONVERT(NVARCHAR(20), 'SKU') + ' '  + 
                               + CONVERT(NVARCHAR(20), 'UCC') + ' '  +
                               + CONVERT(NVARCHAR(10), 'Qty') )
         INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 10))
                                   
         INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
         SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(10), WD.Loc) + ' ' +
         CONVERT(NVARCHAR(20), WD.SKU) + ' ' + 
         CONVERT(NVARCHAR(20), UCC.UCCNo)  + ' ' +
         CONVERT(NVARCHAR(10), UCC.Qty)
         FROM #WaveDetail  WD                              
         JOIN UCC UCC WITH (NOLOCK) ON UCC.Loc = WD.Loc
         WHERE WD.Loc = @c_Loc
         AND   WD.SKU = @c_SKU
         AND   UCC.[STATUS] < '6' 
   	   
         
         
      END
      
      FETCH NEXT FROM CUR_UCC INTO @c_Loc, @c_SKU, @c_StorerKey 
   END
   CLOSE CUR_UCC      
   DEALLOCATE CUR_UCC

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE Length =0 OR Width=0 OR Height=0 OR StdGrossWgt=0)
   BEGIN
 	   SET @b_Success = 0 
      SET @n_err = 75106
      SET @c_ErrMsg = 'Found ZERO Length, Width OR Height'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found ZERO Length, Width OR Height OR Weight')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'SKU') + ' '      
                                 + CONVERT(NVARCHAR(10), 'Length') + ' '  +
                                 + CONVERT(NVARCHAR(10), 'Width')  + ' '  +
                                 + CONVERT(NVARCHAR(10), 'Height') + ' '  + 
                                 + CONVERT(NVARCHAR(10), 'Weight') )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 10) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(20), SKU) + ' ' +
         CONVERT(NVARCHAR(10), [Length]) + ' ' + 
         CONVERT(NVARCHAR(10), Width)  + ' ' +
         CONVERT(NVARCHAR(10), Height) + ' ' + 
         CONVERT(NVARCHAR(10), StdGrossWgt) 
      FROM #WaveDetail 
      WHERE Length =0 OR Width=0 OR Height=0 OR StdGrossWgt=0

	    --GOTO QUIT_SP 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail 
          WHERE Style='' 
          OR Color='' 
          OR [SIZE]='' 
          OR Measurement='' )
   BEGIN
   	SET @b_Success = 0
	   SET @n_err = 75112
	   SET @c_ErrMsg = 'Found BLANK Style, Color, Size OR Measurement'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '---------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found BLANK Style, Color, Size OR Measurement')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '---------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'SKU') + ' '      
                                 + CONVERT(NVARCHAR(20), 'Style') + ' '  +
                                 + CONVERT(NVARCHAR(10), 'Color') + ' '  +
                                 + CONVERT(NVARCHAR(5 ), 'Size')  + ' '  +
                                 + CONVERT(NVARCHAR(10), 'Measurement')  )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 05) + ' ' +
                                   REPLICATE('-', 10) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(20), SKU) + ' ' +
         CONVERT(NVARCHAR(20), Style) + ' ' + 
         CONVERT(NVARCHAR(10), Color) + ' ' +
         CONVERT(NVARCHAR( 5), [SIZE]) + ' ' +
         CONVERT(NVARCHAR(10), Measurement)  
      FROM #WaveDetail 
      WHERE Style='' 
          OR Color='' 
          OR [SIZE]='' 
          OR Measurement=''

	   --GOTO QUIT_SP 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail 
             WHERE Conveyable='' )
   BEGIN
   	 SET @b_Success = 0
	    SET @n_err = 75107
	    SET @c_ErrMsg = 'Found BLANK Conveyable'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '     Found BLANK Conveyable')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'SKU') + ' '      
                                 + CONVERT(NVARCHAR(10), 'Conveyable')  )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 20) + ' ' +
                                   REPLICATE('-', 10) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(20), SKU) + ' ' +
         CONVERT(NVARCHAR(10), Conveyable) 
      FROM #WaveDetail 
      WHERE Conveyable='' 

	    --GOTO QUIT_SP 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE Conveyable='N' AND LocType = 'S')
   BEGIN
   	SET @b_Success = 0 
	   SET @n_err = 75108
	   SET @c_ErrMsg = 'Found NON-Conveyable in a Shelving Location'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found NON-Conveyable in a Shelving Location')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(20), 'SKU') + ' ' 
                                 + CONVERT(NVARCHAR(10), 'Location') + ' '         
                                 + CONVERT(NVARCHAR(10), 'Conveyable')  )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 20) + ' ' + 
                                   REPLICATE('-', 10) + ' ' +
                                   REPLICATE('-', 10) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(20), SKU) + ' ' +
         CONVERT(NVARCHAR(10), Conveyable)
      FROM #WaveDetail 
      WHERE Conveyable='N' AND LocType = 'S'

	   --GOTO QUIT_SP 
   END

   
   IF EXISTS(SELECT LOC FROM #WaveDetail 
             GROUP BY LOC 
             HAVING COUNT(DISTINCT SKU + Lottable02 + LOttable03) > 1)  
   BEGIN
  	   SET @b_Success = 0 
      SET @c_ErrMsg = 'Found Location Contain Multi SKU OR LOT, LOC:' 

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '--------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found Location Contain Multi SKU OR LOT, LOC')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '--------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'Location'))      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 10) )         

	   DECLARE CUR_ZeroPack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT LOC FROM #WaveDetail 
      GROUP BY LOC 
      HAVING COUNT(DISTINCT SKU + Lottable02 + LOttable03) > 1	
      OPEN CUR_ZeroPack 
	   FETCH NEXT FROM CUR_ZeroPack INTO @cCheckLOC
	   WHILE @@FETCH_STATUS <> -1  
	   BEGIN
	   	SET @n_err = 75111
	      SET @c_ErrMsg =  RTRIM(@c_ErrMsg) + RTRIM(@cCheckLOC) + '/'

   	   INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES 
         (@c_WaveKey, CONVERT(NVARCHAR(10), @cCheckLOC))
  	
		   FETCH NEXT FROM CUR_ZeroPack INTO @cCheckLOC
	   END
	   CLOSE CUR_ZeroPack 
	   DEALLOCATE CUR_ZeroPack 
   END

   IF EXISTS(SELECT 1 FROM #WaveDetail WHERE BusinessGroup NOT IN ('JWL', 'APP','ACC'))
   BEGIN
      SET @b_Success = 0    	
	   SET @n_err = 75109 
	   SET @c_ErrMsg = 'Business Group must in JWL, APP or ACC'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')       
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Business Group must in JWL, APP or ACC')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')    
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NVARCHAR(10), 'OrderKey') + ' ' 
                                 + CONVERT(NVARCHAR(20), 'Business Group')  )      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 
                                   REPLICATE('-', 10) + ' ' + 
                                   REPLICATE('-', 20) )         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)   
      SELECT DISTINCT 
         @c_WaveKey,  
         CONVERT(NVARCHAR(10), OrderKey) + ' ' +
         CONVERT(NVARCHAR(20), BusinessGroup) 
      FROM #WaveDetail 

	   --GOTO QUIT_SP 
   END 

   QUIT_SP:
END -- Procedure


GO