SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/          
/* Stored Procedure: ispGenLCIPackingInstruction                                 */          
/* Creation Date: 03-Apr-2012                                                    */          
/* Copyright: IDS                                                                */          
/* Written by: Shong                                                             */          
/*                                                                               */          
/* Purpose:  SOS# - LCI Outbound Placard                                         */          
/*                                                                               */          
/* Called By:  PB - RCM from Wave Screen, Report Type DPSHORTALC                 */          
/*                                                                               */          
/* PVCS Version: 1.0                                                             */          
/*                                                                               */          
/* Version: 5.4                                                                  */          
/*                                                                               */          
/* Data Modifications:                                                           */          
/*                                                                               */          
/* Updates:                                                                      */          
/* Date           Author      Ver.  Purposes                                     */  
/* 05-Apr-2012    Shong       1.1   Bug Fixed                                    */
/* 28-Jan-2019    TLTING_ext  1.2   enlarge externorderkey field length          */
/*********************************************************************************/  
CREATE PROC [dbo].[ispGenLCIPackingInstruction] (
	@cWaveKey NVARCHAR(10) )
AS	
BEGIN 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#Result') IS NOT NULL 
      DROP TABLE #Result
      
   CREATE TABLE #Result (
   	SeqNo          INT IDENTITY(1,1), 
	   ConsoOrderKey  NVARCHAR(30) DEFAULT '',
	   Customer       NVARCHAR(60) DEFAULT '',
	   ShipTo         NVARCHAR(45) DEFAULT '',
	   CustomerType   NVARCHAR(20) DEFAULT '',
	   WaveKey        NVARCHAR(10) DEFAULT '',
	   WaveDate       DATETIME    DEFAULT NULL,
	   LoadKey        NVARCHAR(10) DEFAULT '',
	   TotalQty       INT         DEFAULT 0,
	   PickTicket     NVARCHAR(60) DEFAULT '',        
	   PickQty        INT         DEFAULT 0,
	   ShipWindow     NVARCHAR(60) DEFAULT '',
	   MBOLKey        NVARCHAR(10) DEFAULT '',
	   Carrier        NVARCHAR(60) DEFAULT '',
	   ServiceLevel   NVARCHAR(60) DEFAULT '',
	   MasterPack     NVARCHAR(10) DEFAULT '',
	   PackingList    NVARCHAR(10) DEFAULT '',
	   NewStore       NVARCHAR(10) DEFAULT '',
	   Watch          NVARCHAR(10) DEFAULT '',
	   Jewelry        NVARCHAR(10) DEFAULT '',
	   PackBy         NVARCHAR(10) DEFAULT '',
	   ExternOrderKey NVARCHAR(50) DEFAULT ''   --tlting_ext
	   )

   INSERT INTO #Result (Customer, ShipTo, CustomerType, WaveKey, WaveDate, LoadKey,
               PickTicket, MBOLKey, Carrier, ServiceLevel, MasterPack,
               PackingList, NewStore, PackBy, ConsoOrderKey, ShipWindow, ExternOrderKey)
   SELECT OH.IntermodalVehicle AS Customer,
         OH.C_Company, 
         MAX(ISNULL(RTRIM(OH.Door) ,'')) AS [Retail],
         W.WaveKey, 
         MIN(W.AddDate) AS WaveDate,
         lpd.LoadKey, 
         ISNULL(P.PickSlipNo,''), 
         MAX(OH.MBOLKey) AS MBOL_No, 
         OH.UserDefine02 AS Carrier, 
         CASE WHEN OH.SpecialHandling = 'X' AND FED.Code IS NOT NULL 
              THEN RTRIM(FED.Code) + 
						 + '-'  + RTRIM(FED.Description) + ', ' + RTRIM(FED.Long)  
                   + ', ' + CONVERT(NVARCHAR(250), FED.Notes)
                   + ', ' + CONVERT(NVARCHAR(250), FED.Notes2)
              WHEN OH.SpecialHandling = 'U' AND UPS.Code IS NOT NULL 
              THEN RTRIM(UPS.Code) + 
						 + '-'  + RTRIM(UPS.Description) + ', ' + RTRIM(UPS.Long)  
                   + ', ' + CONVERT(NVARCHAR(250), UPS.Notes)
                   + ', ' + CONVERT(NVARCHAR(250), UPS.Notes2)                    
              ELSE ISNULL(OH.M_Phone2,'') 
         END AS ServiceLevel,
         MAX(CASE SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,8 ,1) 
               WHEN 'Y' THEN 'Y'  
               ELSE 'N'  
             END) AS [MasterPack],
         MAX(SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,9 ,1)) AS [PackList],
         MAX(SUBSTRING(ISNULL(RTRIM(OH.B_Fax1) ,'') ,10 ,1)) AS [NewStore],
         MAX(SUBSTRING(ISNULL(RTRIM(OH.B_FAX1) ,'') , 6, 1)) AS PackMethod, 
         O.ConsoOrderKey, 
         CONVERT(NVARCHAR(12), MIN(OH.OrderDate), 101) + ' - ' + CONVERT(NVARCHAR(12), MAX(OH.DeliveryDate), 101),
         o.ExternConsoOrderKey 
   FROM WAVEDETAIL w (NOLOCK)
   JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = w.OrderKey 
   JOIN ORDERDETAIL o (NOLOCK) ON o.OrderKey = lpd.OrderKey AND o.OrderKey = w.OrderKey 
   LEFT OUTER JOIN PICKDETAIL p (NOLOCK) ON p.OrderKey = o.OrderKey AND p.OrderLineNumber = o.OrderLineNumber 
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = o.OrderKey   
   LEFT OUTER JOIN CODELKUP FED WITH (NOLOCK) ON OH.SpecialHandling = 'X' 
        AND OH.M_Phone2 = FED.Code 
        AND FED.LISTNAME = 'FEDEX_EDI'
   LEFT OUTER JOIN CODELKUP UPS WITH (NOLOCK) ON OH.SpecialHandling = 'U' 
        AND OH.M_Phone2 = UPS.Code 
        AND UPS.LISTNAME = 'UPS_EDI'          
   WHERE w.WaveKey = @cWaveKey 
   GROUP BY W.WaveKey, lpd.LoadKey, 
         o.ConsoOrderKey, 
         OH.IntermodalVehicle,
         OH.C_Company, 
         CASE WHEN OH.SpecialHandling = 'X' AND FED.Code IS NOT NULL 
              THEN RTRIM(FED.Code) + 
						 + '-'  + RTRIM(FED.Description) + ', ' + RTRIM(FED.Long)  
                   + ', ' + CONVERT(NVARCHAR(250), FED.Notes)
                   + ', ' + CONVERT(NVARCHAR(250), FED.Notes2)
              WHEN OH.SpecialHandling = 'U' AND UPS.Code IS NOT NULL 
              THEN RTRIM(UPS.Code) + 
						 + '-'  + RTRIM(UPS.Description) + ', ' + RTRIM(UPS.Long)  
                   + ', ' + CONVERT(NVARCHAR(250), UPS.Notes)
                   + ', ' + CONVERT(NVARCHAR(250), UPS.Notes2)                   
              ELSE ISNULL(OH.M_Phone2, '') 
         END, 
         OH.UserDefine02, 
         ISNULL(P.PickSlipNo,''), 
         O.ConsoOrderKey, 
         o.ExternConsoOrderKey        
   ORDER BY W.WaveKey, lpd.LoadKey, ISNULL(P.PickSlipNo,'')


   UPDATE R
      SET R.TotalQty = OD.Qty
   FROM #Result R  
   JOIN ( 
   SELECT lpd.LoadKey, SUM(o.EnteredQTY) AS Qty 
   FROM ORDERDETAIL o WITH (NOLOCK) 
   JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey 
   WHERE EXISTS(SELECT 1 FROM #Result RST WHERE lpd.LoadKey = RST.LoadKey)
   GROUP BY lpd.LoadKey
   ) AS OD ON OD.LoadKey = R.LoadKey

   UPDATE R
      SET R.PickQty = OD.Qty
   FROM #Result R  
   JOIN ( 
   SELECT ConsoOrderKey, SUM(P.Qty) AS Qty 
   FROM ORDERDETAIL o WITH (NOLOCK) 
   JOIN PICKDETAIL p WITH (NOLOCK) ON p.OrderKey = o.OrderKey AND p.OrderLineNumber = o.OrderLineNumber 
   WHERE EXISTS(SELECT 1 FROM #Result RST WHERE o.ConsoOrderKey = RST.ConsoOrderKey)
   GROUP BY O.ConsoOrderKey
   ) AS OD ON OD.ConsoOrderKey = R.ConsoOrderKey


   UPDATE R
      SET R.Watch   = CASE WHEN OD.[WATCHES] > 0 THEN 'Y' ELSE 'N' END, 
          R.Jewelry = CASE WHEN OD.[JEWELRY] > 0 THEN 'Y' ELSE 'N' END
   FROM #Result R  
   JOIN ( 
   SELECT ConsoOrderKey, 
          SUM(CASE WHEN s.BUSR7 = 'WATCHES' THEN 1 ELSE 0 END) AS [WATCHES],
          SUM(CASE WHEN s.BUSR7 = 'JEWELRY' THEN 1 ELSE 0 END) AS [JEWELRY]  
   FROM ORDERDETAIL o WITH (NOLOCK) 
   JOIN SKU s WITH (NOLOCK) ON s.Sku = o.Sku AND s.StorerKey = o.StorerKey  
   WHERE EXISTS(SELECT 1 FROM #Result RST WHERE o.ConsoOrderKey = RST.ConsoOrderKey)
   GROUP BY O.ConsoOrderKey
   ) AS OD ON OD.ConsoOrderKey = R.ConsoOrderKey

   DECLARE @nSeqNo         INT, 
           @cLoadKey       NVARCHAR(10), 
           @cPickTicket    NVARCHAR(10),  
           @nNoOfPickTkt   INT, 
           @nTotaPickTkt   INT,
           @cPrevLoadKey   NVARCHAR(10)
           
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SeqNo, LoadKey, PickTicket 
   FROM #Result 
   WHERE PickTicket > ''
   ORDER BY LoadKey, PickTicket, SeqNo
   
   OPEN CUR1
   
   SET @cPrevLoadKey = ''
   SET @nNoOfPickTkt = 0
   
   FETCH NEXT FROM CUR1 INTO @nSeqNo, @cLoadKey, @cPickTicket
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cPrevLoadKey <> @cLoadKey
      BEGIN
      	SET @nNoOfPickTkt = 1
      	SET @cPrevLoadKey = @cLoadKey
      END
      ELSE
         SET @nNoOfPickTkt = @nNoOfPickTkt + 1
      
      SELECT @nTotaPickTkt = COUNT(*) 
      FROM #Result WHERE LoadKey = @cLoadKey
      
      
      UPDATE #Result
      SET PickTicket = @cPickTicket + ' ( ' + CAST(@nNoOfPickTkt AS NVARCHAR(5)) + ' of ' + 
          CAST( @nTotaPickTkt as NVARCHAR(5)) +  
          ' )' 
      WHERE SeqNo = @nSeqNo 
      
   	FETCH NEXT FROM CUR1 INTO @nSeqNo, @cLoadKey, @cPickTicket
   END
   CLOSE CUR1
   DEALLOCATE CUR1
   
   
  SELECT ConsoOrderKey
      ,Customer
      ,ShipTo
      ,CustomerType
      ,WaveKey
      ,WaveDate
      ,LoadKey
      ,TotalQty
      ,PickTicket
      ,PickQty
      ,ShipWindow
      ,MBOLKey
      ,Carrier
      ,ServiceLevel
      ,MasterPack
      ,PackingList
      ,NewStore
      ,Watch
      ,Jewelry
      ,PackBy
      ,ExternOrderKey 
FROM   #Result 

END -- Procedure

GO