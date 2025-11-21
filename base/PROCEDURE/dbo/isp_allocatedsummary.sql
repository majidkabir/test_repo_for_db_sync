SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_allocatedsummary                                */  
/* Creation Date:                                                        */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#237620: ALLOC INFO TAB                                   */  
/*                                                                       */  
/* Called By: Call from Loadplan - Show Allocation Summary               */
/*                      Wave - Show Allocation Summary                   */  
/*            datawindow: d_dw_allocated_summary, rptid='01'             */
/*            datawindow: d_dw_allocated_summary_02, rptid='02'          */
/*            datawindow: d_dw_order_planning_wip, rptid='01'            */
/*            datawindow: d_dw_order_planning_unplanned, rptid='01'      */
/*            datawindow: d_dw_order_planning_unplanned_graph1,rptid='02'*/
/*            datawindow: d_dw_order_planning_planned_graph1, rptid='02' */
/*            datawindow: d_dw_order_analytic_wip, rptid='01'            */
/*            datawindow: d_dw_order_analytic_wip_graph1, rptid='02-1'   */
/*            datawindow: d_dw_order_analytic_wip_graph2, rptid='02-2'   */
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 18-APR-2012  YTWan    1.1  SOS#237620:Fixed conversion error when     */
/*                            UDF01, UDF02, UDF03 for MinPerPick has     */
/*                            decimal value.(Wan01)                      */ 
/* 13-APR-2012  YTWan    1.2  SOS#238874. Orders Analytics. (Wan02)      */
/* 27-Feb-2017  TLTING   1.3  variable Nvarchar                          */
/*************************************************************************/  

CREATE PROC [dbo].[isp_allocatedsummary]  
      @c_LoadKey     NVARCHAR(10)
   ,  @c_WaveKey     NVARCHAR(10) 
   ,  @c_RptID       NVARCHAR(2)
   --(Wan02) - START
   ,  @c_AnalyticsType  NVARCHAR(10) = ''
   ,  @c_Facility       NVARCHAR(5)  = 'ALL'
   ,  @dt_StartBf       DATETIME = NULL
   ,  @dt_CancelBf      DATETIME = NULL
   ,  @dt_ShipDTFr      DATETIME = NULL
   ,  @dt_ShipDTTo      DATETIME = NULL 
   --(Wan02) - END   
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Orderkey     NVARCHAR(10)					--(Wan02)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Areakey      NVARCHAR(10)
         , @c_Section      NVARCHAR(10)   
         , @c_Aisle        NVARCHAR(10)					--(Wan02)         
         
			--(Wan02) - START
         , @n_TotalLoads         INT
         , @n_TotalOrders        INT
         , @n_TotalPOs           INT
         , @n_TotalShipTos       INT
         , @n_TotalMarkFors      INT
         , @n_TotalNotLoadOrders INT
         , @n_TotalNotLoadPOs    INT
         , @n_LandUsed           INT
         , @n_AvePalletCube      INT
         , @n_PalletsPOSPerLane  INT         
         --(Wan02) - END
         , @n_TTLCases     		INT
         , @n_FullPallet   		INT
         , @n_Cases        		INT
         , @n_Pieces       		INT
         
			--(Wan02) - START
         , @n_OpenFP             INT
         , @n_OpenPP             INT
         , @n_OpenPC             INT

         , @n_NoOfFPPTask        INT
         , @n_NoOfPPPTask        INT
         , @n_NoOfOPKTask        INT
         , @n_NoOfPKTask         INT
         , @n_NoOfComplPKTask    INT
         , @n_PerctgComplTask    INT
         , @n_NoOfExcpts         INT

         , @n_UsedHRPerctg       DECIMAL(10,2)
         , @n_RemainHRPerctg     DECIMAL(10,2)

         , @c_Pick               NVARCHAR(1)
         --(Wan02) - END
                
   SET @c_Orderkey         = ''					--(Wan02)                
   SET @c_Storerkey  		= ''
   SET @c_Areakey    		= ''
   SET @c_Section    		= '' 
   SET @c_Aisle            = ''					--(Wan02)
   
   SET @n_TTLCases   		= 0
   SET @n_FullPallet 		= 0
   SET @n_Cases      		= 0
   SET @n_Pieces     		= 0

	--(Wan02) - START
   SET @n_OpenFP           = 0                                    
   SET @n_OpenPP           = 0                                    
   SET @n_OpenPC           = 0                                    
                                                                  
   SET @n_NoOfFPPTask      = 0                                    
   SET @n_NoOfPPPTask      = 0                                    
   SET @n_NoOfOPKTask      = 0                                    
   SET @n_NoOfPKTask       = 0                                    
   SET @n_NoOfComplPKTask  = 0                                    
   SET @n_PerctgComplTask  = 0                                    
   SET @n_NoOfExcpts       = 0                                    
                                                                  
   SET @n_UsedHRPerctg     = 0                                    
   SET @n_RemainHRPerctg   = 0                                    
                
                               
   IF @c_AnalyticsType IN ('','A-WIP','P-WIP', 'P-UNPLAN') SET @c_Pick = ''
   IF @c_AnalyticsType = 'P-PLANNED' SET @c_Pick = 'N'
   
   
      CREATE TABLE #Temp_pick (
        Loadkey            NVARCHAR(10)       NOT NULL DEFAULT('')
      , Wavekey            NVARCHAR(10)       NOT NULL DEFAULT('')
      , Orderkey           NVARCHAR(10)    NULL     DEFAULT('')
      , Dockey             NVARCHAR(10)       NOT NULL DEFAULT('')
      , Storerkey          NVARCHAR(15)    NOT NULL DEFAULT('')
      , TotalLoads         INT            NULL     DEFAULT(0)
      , TotalOrders        INT            NULL     DEFAULT(0)
      , TotalPOs           INT            NULL     DEFAULT(0)
      , TotalShipTos       INT            NULL     DEFAULT(0)    
      , TotalMarkFors      INT            NULL     DEFAULT(0)
      , TotalNotLoadOrders INT            NULL     DEFAULT(0)
      , TotalNotLoadPOs    INT            NULL     DEFAULT(0)
      , Section            NVARCHAR(10)    NULL     DEFAULT('')
      , Areakey            NVARCHAR(10)    NULL     DEFAULT('')   
      , Aisle              NVARCHAR(10)    NULL     DEFAULT('')  
      , NoOfLocs           INT            NULL     DEFAULT('')
      , TTLCases           INT            NULL     DEFAULT('')
      , FullPallet         INT            NULL     DEFAULT(0)
      , Cases              INT            NULL     DEFAULT(0)
      , Pieces             INT            NULL     DEFAULT(0)
      , OpenFP             INT            NULL     DEFAULT(0)
      , OpenPP             INT            NULL     DEFAULT(0)
      , OpenPC             INT            NULL     DEFAULT(0)
      , MaxPallet          INT            NULL     DEFAULT(0)
      , LaneUsed           INT            NULL     DEFAULT(0)
      , [Cube]               FLOAT          NULL     DEFAULT(0.00)
      , AvePalletCube      FLOAT          NULL     DEFAULT(0.00)
      , PalletsPOSPerLane  FLOAT          NULL     DEFAULT(0.00)
      --(Wan01) - START
      , MinPerFPPick       FLOAT          NULL     DEFAULT(0.00)
      , MinPerCSPick       FLOAT          NULL     DEFAULT(0.00)
      , MinPerPCSPick      FLOAT          NULL     DEFAULT(0.00)
      --(Wan01) - END
      , NoOfFPPTask        INT            NULL     DEFAULT(0)
      , NoOfPPPTask        INT            NULL     DEFAULT(0)
      , NoOfOPKTask        INT            NULL     DEFAULT(0)
      , NoOfPKTask         INT            NULL     DEFAULT(0)
      , NoOfComplPKTask    INT            NULL     DEFAULT(0)
      , PerctgComplTask    INT            NULL     DEFAULT(0)
      , NoOfExcpts         INT            NULL     DEFAULT(0))

   CREATE INDEX IDX_PICK_Unique ON #Temp_pick (Loadkey, Wavekey, Storerkey, Section, Areakey, Aisle)
   CREATE INDEX IDX_PICK_Orderkey ON #Temp_pick (Orderkey, Storerkey)

   IF @c_AnalyticsType = '' 
   BEGIN
      IF @c_WaveKey = ''
      BEGIN
         INSERT INTO #Temp_pick
               ( LoadKey
               , Wavekey
               , DOCkey
               , Storerkey
               , TotalOrders
               , TotalPOs
               , TotalShipTos
               , TotalMarkFors
               , Section 
               , Areakey
               , NoOfLocs
               , TTLCases
               , [Cube]
               , AvePalletCube
               , PalletsPOSPerLane
               , MinPerFPPick
               , MinPerCSPick
               , MinPerPCSPick)
         SELECT LOADPLANDETAIL.LoadKey
               ,''
               ,LOADPLANDETAIL.LoadKey
               ,ISNULL(RTRIM(ORDERS.Storerkey),'')
               ,COUNT(DISTINCT ORDERS.Orderkey)
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
               ,ISNULL(RTRIM(LOC.SectionKey),'') 
               ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
               ,COUNT(DISTINCT PICKDETAIL.LOC)
               ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PICKDETAIL.Qty / PACK.CaseCnt ELSE 0 END),0))
               ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
               ,ISNULL(CLL.UDF01,0)
               ,ISNULL(CLL.UDF02,0)
               ,ISNULL(CLM.UDF01,0)
               ,ISNULL(CLM.UDF02,0)
               ,ISNULL(CLM.UDF03,0)
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
         JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
         JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                 AND(PICKDETAIL.Sku = SKU.Sku)
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
         LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
         LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')
                                             AND(ORDERS.Storerkey= CLL.Code) 
         LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick')
                                               AND(ORDERS.Storerkey= CLM.Storerkey) 
                                               AND(ORDERs.Facility = CLM.Code) 

         WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey
         GROUP BY LOADPLANDETAIL.LoadKey
                 ,ISNULL(RTRIM(ORDERS.Storerkey),'')
                 ,ISNULL(RTRIM(LOC.SectionKey),'') 
                 ,ISNULL(RTRIM(AREADETAIL.Areakey),'')
                 ,ISNULL(CLL.UDF01,0)
                 ,ISNULL(CLL.UDF02,0)
                 ,ISNULL(CLM.UDF01,0)
                 ,ISNULL(CLM.UDF02,0)
                 ,ISNULL(CLM.UDF03,0) 

      END
      ELSE
      BEGIN
         INSERT INTO #Temp_pick
               ( LoadKey
               , Wavekey
               , DOCkey
               , Storerkey
               , TotalOrders
               , TotalPOs
               , TotalShipTos
               , TotalMarkFors
               , Section 
               , Areakey
               , NoOfLocs
               , TTLCases
               , [Cube]
               , AvePalletCube
               , PalletsPOSPerLane
               , MinPerFPPick
               , MinPerCSPick
               , MinPerPCSPick)
         SELECT ''
               ,WAVEDETAIL.Wavekey
               ,WAVEDETAIL.Wavekey
               ,ISNULL(RTRIM(ORDERS.Storerkey),'')
               ,COUNT(DISTINCT ORDERS.Orderkey)
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
               ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
               ,ISNULL(RTRIM(LOC.SectionKey),'') 
               ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
               ,COUNT(DISTINCT PICKDETAIL.LOC)
               ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PICKDETAIL.Qty / PACK.CaseCnt ELSE 0 END),0))
               ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
               ,ISNULL(CLL.UDF01,0)
               ,ISNULL(CLL.UDF02,0)
               ,ISNULL(CLM.UDF01,0)
               ,ISNULL(CLM.UDF02,0)
               ,ISNULL(CLM.UDF03,0)
         FROM WAVEDETAIL WITH (NOLOCK)
         JOIN ORDERS     WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
         JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
         JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                 AND(PICKDETAIL.Sku = SKU.Sku)
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
         LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
         LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')
                                             AND(ORDERS.Storerkey= CLL.Code) 
         LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick')
                                               AND(ORDERS.Storerkey= CLM.Storerkey) 
                                               AND(ORDERs.Facility = CLM.Code) 

         WHERE WAVEDETAIL.WaveKey = @c_Wavekey
         GROUP BY ORDERS.LoadKey
                 ,WAVEDETAIL.Wavekey
                 ,ISNULL(RTRIM(ORDERS.Storerkey),'')
                 ,ISNULL(RTRIM(LOC.SectionKey),'') 
                 ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
                 ,ISNULL(CLL.UDF01,0)
                 ,ISNULL(CLL.UDF02,0)
                 ,ISNULL(CLM.UDF01,0)
                 ,ISNULL(CLM.UDF02,0)
                 ,ISNULL(CLM.UDF03,0)

      END
   END
   --(Wan02) - START
   ELSE IF @c_AnalyticsType IN ('P-WIP','A-WIP')  -- Task Release
   BEGIN
      SELECT @n_TotalLoads   = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.LoadKey),''))
            ,@n_TotalOrders  = COUNT(DISTINCT ORDERS.Orderkey)
            ,@n_TotalPOs     = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
            ,@n_TotalShipTos = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
            ,@n_TotalMarkFors= COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
            ,@n_LandUsed     = COUNT(DISTINCT DID.DropLoc)

      FROM ORDERS     WITH (NOLOCK)
      JOIN LOADPLAN   WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
      LEFT JOIN MBOL       WITH (NOLOCK) ON (ORDERS.MBOLkey = MBOL.MBOLkey)
      LEFT JOIN LOADPLANLANEDETAIL LPLD WITH (NOLOCK) ON (LOADPLAN.Loadkey = LPLD.Loadkey) AND (LPLD.LocationCategory = 'STAGING')
      LEFT JOIN DROPID DID WITH (NOLOCK) ON (LPLD.Loadkey = DID.Loadkey) AND (LPLD.LOC = DID.Droploc) 
                                         AND(DID.AdditionalLoc = '') AND (DID.Status = '9') 
      WHERE LOADPLAN.ProcessFlag IN ('L', 'Y')
      AND   ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
--      AND   CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) >= CASE WHEN ISNULL(@dt_ShipDTFr,'19000101') = '19000101' THEN CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) ELSE CONVERT( VARCHAR(10),@dt_ShipDTFr,112) END
--      AND   CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) <= CASE WHEN ISNULL(@dt_ShipDTTo,'19000101') = '19000101' THEN CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) ELSE CONVERT( VARCHAR(10),@dt_ShipDTTo,112) END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') >= CASE WHEN ISNULL(@dt_ShipDTFr,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTFr END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') <= CASE WHEN ISNULL(@dt_ShipDTTo,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTTo END 
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(@c_LoadKey,'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status >= '2' AND ORDERS.Status < '9'

      INSERT INTO #Temp_pick ( 
                 Loadkey
               , Wavekey
               , DOCkey
               , Storerkey
               , TotalLoads
               , TotalOrders
               , TotalPOs
               , TotalShipTos
               , TotalMarkFors
               , Section 
               , Areakey
               , Aisle
               --, NoOfLocs
               , TTLCases
               , MaxPallet
               , LaneUsed
               , [Cube]
               , AvePalletCube
               , PalletsPOSPerLane
               , MinPerFPPick
               , MinPerCSPick
               , MinPerPCSPick)

      SELECT ISNULL(RTRIM(ORDERS.Loadkey),'')
            ,''
            ,ISNULL(RTRIM(ORDERS.Loadkey),'')
            ,ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,@n_TotalLoads
            ,@n_TotalOrders
            ,@n_TotalPOs
            ,@n_TotalShipTos
            ,@n_TotalMarkFors
            ,ISNULL(RTRIM(LOC.SectionKey),'') 
            ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
            ,ISNULL(RTRIM(LOC.LocAisle),'') 
            --,COUNT(DISTINCT PICKDETAIL.LOC)
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PICKDETAIL.Qty / PACK.CaseCnt ELSE 0 END),0))
            , ISNULL( ( SELECT TOP 1 LOC.MaxPallet
                  FROM LOADPLANLANEDETAIL WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOADPLANLANEDETAIL.Loc = LOC.Loc)
                  WHERE LOADPLANLANEDETAIL.Loadkey = ISNULL(RTRIM(ORDERS.Loadkey),'')
                  AND LOC.LocationCategory = 'STAGING'
                  ORDER BY LOADPLANLANEDETAIL.LP_LaneNumber ) ,0)
            ,@n_LandUsed
            ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
            ,ISNULL(CLL.UDF01,0)
            ,ISNULL(CLL.UDF02,0)
            ,ISNULL(CLM.UDF01,0)
            ,ISNULL(CLM.UDF02,0)
            ,ISNULL(CLM.UDF03,0)
      FROM ORDERS     WITH (NOLOCK)
      JOIN LOADPLAN   WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
      LEFT JOIN MBOL       WITH (NOLOCK) ON (ORDERS.MBOLkey = MBOL.MBOLkey)
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey) AND(PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
      LEFT JOIN AREADETAIL WITH (NOLOCK)   ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
      LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick') AND(ORDERS.Storerkey= CLM.Storerkey) 
                                           AND(ORDERs.Facility = CLM.Code) 
      LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')  AND(ORDERS.Storerkey= CLL.Code)                             
      WHERE LOADPLAN.ProcessFlag IN ('L', 'Y')
      AND   ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
--      AND   CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) >= CASE WHEN ISNULL(@dt_ShipDTFr,'19000101') = '19000101' THEN CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) ELSE CONVERT( VARCHAR(10),@dt_ShipDTFr,112) END
--      AND   CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) <= CASE WHEN ISNULL(@dt_ShipDTTo,'19000101') = '19000101' THEN CONVERT( VARCHAR(10),MBOL.ArrivalDate, 112) ELSE CONVERT( VARCHAR(10),@dt_ShipDTTo,112) END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') >= CASE WHEN ISNULL(@dt_ShipDTFr,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTFr END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') <= CASE WHEN ISNULL(@dt_ShipDTTo,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTTo END 
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(@c_LoadKey,'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status >= '2' AND ORDERS.Status < '9'
      GROUP BY ISNULL(RTRIM(ORDERS.Loadkey),'')
              ,ISNULL(RTRIM(ORDERS.Storerkey),'')
              ,ISNULL(RTRIM(LOC.SectionKey),'') 
              ,ISNULL(RTRIM(AREADETAIL.Areakey),'')
              ,ISNULL(RTRIM(LOC.LocAisle),'') 
              ,ISNULL(CLL.UDF01,0)
              ,ISNULL(CLL.UDF02,0)
              ,ISNULL(CLM.UDF01,0)
              ,ISNULL(CLM.UDF02,0)
              ,ISNULL(CLM.UDF03,0) 

   END 
   ELSE IF @c_AnalyticsType = 'P-PLANNED' -- Allocated But No Task Release   
   BEGIN
      SELECT @n_TotalLoads   = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.LoadKey),''))
            ,@n_TotalOrders  = COUNT(DISTINCT ORDERS.Orderkey)
            ,@n_TotalPOs     = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
            ,@n_TotalShipTos = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
            ,@n_TotalMarkFors=COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
      FROM ORDERS     WITH (NOLOCK)
      JOIN LOADPLAN   WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
      LEFT JOIN MBOL       WITH (NOLOCK) ON (ORDERS.MBOLkey = MBOL.MBOLkey)
      WHERE LOADPLAN.ProcessFlag IN ('N')
      AND   ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') >= CASE WHEN ISNULL(@dt_ShipDTFr,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTFr END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') <= CASE WHEN ISNULL(@dt_ShipDTTo,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTTo END 
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status IN ('1', '2')

      -- Count Loadkey for loadplan with no orderkey populated to Loadplan
      IF ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' AND ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' AND 
         ISNULL(@dt_ShipDTTo,'1900-01-01') = '1900-01-01'
      BEGIN
         SELECT @n_TotalLoads = @n_TotalLoads + COUNT(DISTINCT ISNULL(RTRIM(LOADPLAN.LoadKey),''))
         FROM LOADPLAN WITH (NOLOCK)
         WHERE LOADPLAN.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN LOADPLAN.Facility ELSE RTRIM(@c_Facility) END
         AND   LOADPLAN.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN LOADPLAN.Loadkey ELSE RTRIM(@c_LoadKey) END
         AND   LOADPLAN.Status IN ('1', '2')
         AND   NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)
                           WHERE LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)
      END

      INSERT INTO #Temp_pick ( 
                 Loadkey
               , Wavekey
               , DOCkey
               , Storerkey
               , TotalLoads
               , TotalOrders
               , TotalPOs
               , TotalShipTos
               , TotalMarkFors
               , Section 
               , Areakey
               --, NoOfLocs
               , TTLCases
               , [Cube]
               , AvePalletCube
               , PalletsPOSPerLane
               , MinPerFPPick
               , MinPerCSPick
               , MinPerPCSPick)
      SELECT ISNULL(RTRIM(ORDERS.Loadkey),'')
            ,''
            ,ISNULL(RTRIM(ORDERS.Loadkey),'')
            ,ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,@n_TotalLoads
            ,@n_TotalOrders
            ,@n_TotalPOs
            ,@n_TotalShipTos
            ,@n_TotalMarkFors
            ,ISNULL(RTRIM(LOC.SectionKey),'') 
            ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
            --,COUNT(DISTINCT PICKDETAIL.LOC)
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PICKDETAIL.Qty / PACK.CaseCnt ELSE 0 END),0))
            ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
            ,ISNULL(CLL.UDF01,0)
            ,ISNULL(CLL.UDF02,0)
            ,ISNULL(CLM.UDF01,0)
            ,ISNULL(CLM.UDF02,0)
            ,ISNULL(CLM.UDF03,0)
      FROM ORDERS     WITH (NOLOCK)
      LEFT JOIN LOADPLAN   WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey) AND (PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
      LEFT JOIN MBOL       WITH (NOLOCK) ON (ORDERS.MBOLkey = MBOL.MBOLkey)
      LEFT JOIN AREADETAIL WITH (NOLOCK)   ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
      LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')  AND(ORDERS.Storerkey= CLL.Code) 
      LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick') AND(ORDERS.Storerkey= CLM.Storerkey) 
                                           AND(ORDERs.Facility = CLM.Code) 
      WHERE LOADPLAN.ProcessFlag IN ('N')
      AND   ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') >= CASE WHEN ISNULL(@dt_ShipDTFr,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTFr END
      AND   ISNULL(MBOL.ArrivalDate,'1900-01-01') <= CASE WHEN ISNULL(@dt_ShipDTTo,'1900-01-01') = '1900-01-01' THEN ISNULL(MBOL.ArrivalDate,'1900-01-01') ELSE @dt_ShipDTTo END 
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status IN ('1', '2')
      GROUP BY ISNULL(RTRIM(ORDERS.Loadkey),'')
              ,ISNULL(RTRIM(ORDERS.Storerkey),'')
              ,ISNULL(RTRIM(LOC.SectionKey),'') 
              ,ISNULL(RTRIM(AREADETAIL.Areakey),'')
              --,ISNULL(RTRIM(LOC.LocAisle),'') 
              ,ISNULL(CLL.UDF01,0)
              ,ISNULL(CLL.UDF02,0)
              ,ISNULL(CLM.UDF01,0)
              ,ISNULL(CLM.UDF02,0)
              ,ISNULL(CLM.UDF03,0)

      --To Show total Loads on Screen if there is any loadplans with no orderkey populated to loadplan and loadplan status in ('1','2') 
      IF @n_TotalLoads > 0 AND NOT EXISTS (SELECT 1 FROM #Temp_pick)
      BEGIN 
         INSERT #Temp_pick ( TotalLoads )
         VALUES ( @n_TotalLoads)
         
         GOTO QUIT
      END  
   END
   ELSE IF @c_AnalyticsType = 'P-UNPLAN' -- Not in Load or not allocated
   BEGIN
      SELECT @n_TotalNotLoadOrders = COUNT(DISTINCT ORDERS.Orderkey)
            ,@n_TotalNotLoadPOs    = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
      FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status = '0'
      AND   (ORDERS.Loadkey IS NULL OR ISNULL(RTRIM(ORDERS.LoadKey),'') = '')


      SELECT @n_TotalLoads   = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.LoadKey),''))
      FROM ORDERS WITH (NOLOCK)
      JOIN LOADPLANDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
      WHERE ORDERS.Facility  = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status = '0'   
      AND   NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                        WHERE LPD.Loadkey = LOADPLANDETAIL.Loadkey
                        AND LPD.Status > '0')

      -- Count Loadkey for loadplan with no orderkey populated to Loadplan
      IF ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' AND ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01'
      BEGIN
         SELECT @n_TotalLoads = @n_TotalLoads + COUNT(DISTINCT ISNULL(RTRIM(LOADPLAN.LoadKey),''))
         FROM LOADPLAN WITH (NOLOCK)
         WHERE LOADPLAN.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN LOADPLAN.Facility ELSE RTRIM(@c_Facility) END
         AND   LOADPLAN.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN LOADPLAN.Loadkey ELSE RTRIM(@c_LoadKey) END
         AND   LOADPLAN.Status = '0'
         AND   NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)
                           WHERE LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)
      END

      SELECT @n_TotalOrders  = COUNT(DISTINCT ORDERS.Orderkey)
            ,@n_TotalPOs     = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
            ,@n_TotalShipTos = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
            ,@n_TotalMarkFors =COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
      FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.Facility  = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status = '0'


      INSERT INTO #Temp_pick (
                 Loadkey
               , Wavekey
               , Orderkey
               , DOCkey
               , Storerkey
               , TotalLoads
               , TotalOrders
               , TotalPOs
               , TotalShipTos
               , TotalMarkFors
               , TotalNotLoadOrders
               , TotalNotLoadPOs
               , TTLCases
               , FullPallet
               , Cases
               , Pieces
               , [Cube]
               , AvePalletCube
               , PalletsPOSPerLane
               , MinPerFPPick
               , MinPerCSPick
               , MinPerPCSPick)
      SELECT ISNULL(RTRIM(ORDERS.Orderkey),'')
            ,''
            ,ISNULL(RTRIM(ORDERS.Orderkey),'')
            ,ISNULL(RTRIM(ORDERS.Orderkey),'')
            ,ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,@n_TotalLoads
            ,@n_TotalOrders
            ,@n_TotalPOs
            ,@n_TotalShipTos
            ,@n_TotalMarkFors
            ,@n_TotalNotLoadOrders
            ,@n_TotalNotLoadPOs
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN ORDERDETAIL.OpenQty / PACK.CaseCnt ELSE 0 END),0))
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.Pallet,0)  > 0 THEN ORDERDETAIL.OpenQty / PACK.Pallet ELSE 0 END),0))
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.CaseCnt,0) > 0
                                   THEN (ORDERDETAIL.OpenQty %  CONVERT(INT,PACK.Pallet)) / PACK.CaseCnt 
                                   WHEN ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.CaseCnt,0) > 0
                                   THEN ORDERDETAIL.OpenQty / PACK.CaseCnt 
                                   ELSE 0 END),0))
            ,FLOOR(ISNULL(SUM(CASE WHEN ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.CaseCnt,0) > 0 
                                   THEN (ORDERDETAIL.OpenQty % CONVERT(INT,PACK.Pallet)) %  CONVERT(INT,PACK.CaseCnt) 
                                   WHEN ISNULL(PACK.Pallet,0) > 0 AND ISNULL(PACK.CaseCnt,0) = 0
                                   THEN ORDERDETAIL.OpenQty %  CONVERT(INT,PACK.Pallet)
                                   WHEN ISNULL(PACK.Pallet,0) = 0 AND ISNULL(PACK.CaseCnt,0) > 0
                                   THEN ORDERDETAIL.OpenQty %  CONVERT(INT,PACK.CaseCnt)
                                   ELSE ORDERDETAIL.OpenQty END),0))
            ,ISNULL(SUM(ORDERDETAIL.OpenQty * SKU.StdCube),0.00) 
            ,ISNULL(CLL.UDF01,0)
            ,ISNULL(CLL.UDF02,0)
            ,ISNULL(CLM.UDF01,0)
            ,ISNULL(CLM.UDF02,0)
            ,ISNULL(CLM.UDF03,0)
      FROM ORDERS WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK)       ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU  WITH (NOLOCK)              ON (ORDERDETAIL.Storerkey = SKU.Storerkey) AND (ORDERDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK)              ON (ORDERDETAIL.Packkey = PACK.Packkey)
      LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')  AND(ORDERS.Storerkey= CLL.Code) 
      LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick') AND(ORDERS.Storerkey= CLM.Storerkey) 
                                           AND(ORDERs.Facility = CLM.Code) 
      WHERE ORDERS.Facility = CASE WHEN ISNULL(RTRIM(@c_Facility),'ALL') = 'ALL' THEN ORDERS.Facility ELSE RTRIM(@c_Facility) END
      AND   ORDERS.OrderDate <= CASE WHEN ISNULL(@dt_StartBf,'1900-01-01') = '1900-01-01' THEN ORDERS.OrderDate ELSE @dt_StartBf END
      AND   ORDERS.DeliveryDate <= CASE WHEN ISNULL(@dt_CancelBf,'1900-01-01') = '1900-01-01' THEN ORDERS.DeliveryDate ELSE @dt_CancelBf END
      AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'ALL') = 'ALL' THEN ORDERS.Loadkey ELSE RTRIM(@c_LoadKey) END
      AND   ORDERS.Status = '0'
      GROUP BY ISNULL(RTRIM(ORDERS.Orderkey),'')
              ,ISNULL(RTRIM(ORDERS.Storerkey),'')
              ,ISNULL(CLL.UDF01,0)
              ,ISNULL(CLL.UDF02,0)
              ,ISNULL(CLM.UDF01,0)
              ,ISNULL(CLM.UDF02,0)
              ,ISNULL(CLM.UDF03,0) 

      --To Show total Loads on Screen if there is any loadplans with no orderkey populated to loadplan and loadplan status ='0' 
      IF @n_TotalLoads > 0 AND NOT EXISTS (SELECT 1 FROM #Temp_pick)
      BEGIN 
         INSERT #Temp_pick ( TotalLoads )
         VALUES ( @n_TotalLoads)
         
         GOTO QUIT
      END 

      DECLARE C_OrdInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT Orderkey
            ,Storerkey
      FROM #Temp_pick
      OPEN C_OrdInfo  
      FETCH NEXT FROM C_OrdInfo INTO @c_Orderkey, @c_Storerkey 

      WHILE (@@FETCH_STATUS<>-1)  
      BEGIN
         IF EXISTS ( SELECT 1   
                     FROM STORERCONFIG SC WITH (NOLOCK) 
                     WHERE SC.Storerkey = @c_Storerkey
                     AND   SC.Configkey = 'PrePackByBOM'   
                     AND   SC.SValue = '1' ) 
            AND
            EXISTS ( SELECT 1   
                     FROM STORERCONFIG SC WITH (NOLOCK) 
                     WHERE SC.Storerkey = @c_Storerkey  
                     AND   SC.Configkey = 'PrePackConsoAllocation'   
                     AND   SC.SValue = '1' )
         BEGIN
            EXEC isp_GetOrdPPKPltCase
                 @c_Orderkey
               , ''  
               , '' 
               , @n_Cases        OUTPUT 
               , @n_FullPallet   OUTPUT  
               , @n_Pieces       OUTPUT 
               , @n_TTLCases     OUTPUT 

            UPDATE #Temp_pick WITH (ROWLOCK)
            SET TTLCases   = @n_TTLCases
               ,FullPallet = @n_FullPallet
               ,Cases      = @n_Cases
               ,Pieces     = @n_Pieces
            WHERE Orderkey = @c_Orderkey
            AND   Storerkey = @c_Storerkey

         END

         FETCH NEXT FROM C_OrdInfo INTO @c_ORderkey, @c_Storerkey  
      END
      CLOSE C_OrdInfo
      DEALLOCATE C_OrdInfo

      GOTO QUIT
   END
   --(Wan02) - END

   DECLARE C_PickInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT 
          Loadkey
         ,Wavekey
         ,Storerkey
         ,Section    
         ,AreaKey
         ,Aisle                                                                                    --(Wan02)
   FROM #Temp_pick

   OPEN C_PickInfo  
   FETCH NEXT FROM C_PickInfo INTO @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Section, @c_Areakey, @c_Aisle         --(Wan02)  

   WHILE (@@FETCH_STATUS<>-1)  
   BEGIN  
      IF EXISTS ( SELECT 1   
                  FROM STORERCONFIG SC WITH (NOLOCK) 
                  WHERE SC.Storerkey = @c_Storerkey
                  AND   SC.Configkey = 'PrePackByBOM'   
                  AND   SC.SValue = '1' ) AND
         EXISTS ( SELECT 1   
                  FROM STORERCONFIG SC WITH (NOLOCK) 
                  WHERE SC.Storerkey = @c_Storerkey  
                  AND   SC.Configkey = 'PrePackConsoAllocation'   
                  AND   SC.SValue = '1' )
      BEGIN
         --(Wan02) - START
         SET @c_Pick = ''
         IF @c_AnalyticsType IN ( 'P-WIP', 'A-WIP')
         BEGIN 
            
            EXEC isp_GetPPKPltCase2 
                 @c_LoadKey
               , ''  
               , '' 
               , @n_OpenPP   OUTPUT 
               , @n_OpenFP   OUTPUT  
               , @n_OpenPC   OUTPUT   
               ,''  
               ,''  
               ,'N' --@c_Pick 
               ,'Y' --@c_GetTotPallet
               ,@c_Storerkey
               ,@c_Wavekey
               ,@c_Section                                                                   
               ,@c_Areakey
               ,@c_Aisle                                                                           
         END
         ELSE IF @c_AnalyticsType = 'P-PLANNED'
         BEGIN
            SET @c_Pick = 'N'
         END
         --(Wan02) - END
         EXEC isp_GetPPKPltCase2 
              @c_LoadKey
            , ''  
            , '' 
            , @n_Cases        OUTPUT 
            , @n_FullPallet   OUTPUT  
            , @n_Pieces       OUTPUT   
            ,''  
            ,''  
            ,@c_Pick
            ,'Y' --@c_GetTotPallet
            ,@c_Storerkey
            ,@c_Wavekey
            ,@c_Section                                                                   
            ,@c_Areakey
            ,@c_Aisle                                                                              --(Wan02)

         EXEC isp_GetPPKPltCase2 
              @c_LoadKey
            , ''  
            , '' 
            , @n_TTLCases     OUTPUT 
            , 0 
            , 0   
            ,''  
            ,''  
            ,@c_Pick 
            ,'N' --@c_GetTotPallet
            ,@c_Storerkey
            ,@c_Wavekey
            ,@c_Section                                                                   
            ,@c_Areakey
            ,@c_Aisle                                                                              --(Wan02)
      END
      ELSE
      BEGIN
         --(Wan02) - START
         IF @c_AnalyticsType IN ( 'P-WIP', 'P-PLANNED', 'A-WIP')
         BEGIN
            SELECT @n_FullPallet = ISNULL(SUM(FP),0)
                  ,@n_Cases = ISNULL(SUM(FLOOR(CS)),0)  
                  ,@n_Pieces= ISNULL(SUM(PCS),0)
                  ,@n_TTLCases = ISNULL(SUM(TTLCases),0)
            FROM (
               SELECT FP = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 1 ELSE 0 END 
                     ,CS = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0  
                                ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END 
                           END               
                     ,PCS= CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0 
                                ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) % CONVERT(NUMERIC,ISNULL(PACK.CaseCnt,0))
                                          ELSE SUM(PICKDETAIL.Qty) 
                                     END 
                           END
                     ,TTLCases = FLOOR(ISNULL(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / PACK.CaseCnt ELSE 0 END,0))
               FROM ORDERS WITH (NOLOCK)
               JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
               JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey) 
               JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey) AND (PICKDETAIL.SKU = SKU.SKU)
               JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
               JOIN ( SELECT Loc
                           , Id
                           , Qty = SUM (Qty)
                      FROM LOTxLOCxID WITH (NOLOCK) 
                      WHERE Storerkey = @c_Storerkey 
                      GROUP BY Loc
                              ,Id ) LLI ON (PICKDETAIL.Loc= LLI.Loc)
                                        AND(PICKDETAIL.Id = LLI.Id)
               LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
               WHERE ORDERS.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN ORDERS.Loadkey ELSE  @c_LoadKey END
               AND   ORDERS.UserDefine09 = CASE WHEN ISNULL(@c_Wavekey ,'')='' THEN ORDERS.UserDefine09 ELSE @c_Wavekey END
               AND   LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END
               AND   ORDERS.Storerkey = @c_Storerkey
               AND   LOC.Sectionkey = @c_Section
               AND   ISNULL(RTRIM(AREADETAIL.Areakey),'') = @c_AreaKey
               AND   PICKDETAIL.Status <= '4'
               GROUP BY PICKDETAIL.LOC 
                     ,  PICKDETAIL.ID 
                     ,  PICKDETAIL.Status
                     ,  LLI.Qty
                     ,  PACK.CaseCnt ) T

            IF @c_AnalyticsType IN ('P-WIP','A-WIP')
            BEGIN
               SET @n_OpenFP = @n_FullPallet
               SET @n_OpenPP = @n_Cases
               SET @n_OpenPC = @n_Pieces
            END
         END 

         IF @c_AnalyticsType IN ('', 'P-WIP', 'A-WIP')
         BEGIN
         --(Wan02) - END
            SELECT @n_FullPallet = ISNULL(SUM(FP),0)
                  ,@n_Cases = ISNULL(SUM(FLOOR(CS)),0)  
                  ,@n_Pieces= ISNULL(SUM(PCS),0)
                  ,@n_TTLCases = ISNULL(SUM(TTLCases),0)
            FROM (
               SELECT FP = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 1 ELSE 0 END 
                     ,CS = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0  
                                ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END 
                           END               
                     ,PCS= CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0 
                                ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) % CONVERT(NUMERIC,ISNULL(PACK.CaseCnt,0))
                                          ELSE SUM(PICKDETAIL.Qty) 
                                     END 
                           END
                     ,TTLCases = FLOOR(ISNULL(CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / PACK.CaseCnt ELSE 0 END,0))
               FROM ORDERS WITH (NOLOCK)
               JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey)
               JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey) 
               JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey) AND (PICKDETAIL.SKU = SKU.SKU)
               JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
               JOIN ( SELECT Loc
                           , Id
                           , Qty = SUM (Qty)
                      FROM LOTxLOCxID WITH (NOLOCK) 
                      WHERE Storerkey = @c_Storerkey 
                      GROUP BY Loc
                              ,Id ) LLI ON (PICKDETAIL.Loc= LLI.Loc)
                                        AND(PICKDETAIL.Id = LLI.Id)
               LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
               WHERE ORDERS.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN ORDERS.Loadkey ELSE  @c_LoadKey END
               AND   ORDERS.UserDefine09 = CASE WHEN ISNULL(@c_Wavekey ,'')='' THEN ORDERS.UserDefine09 ELSE @c_Wavekey END
               AND   LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END
               AND   ORDERS.Storerkey = @c_Storerkey
               AND   LOC.Sectionkey = @c_Section
               AND   ISNULL(RTRIM(AREADETAIL.Areakey),'') = @c_AreaKey
               AND   PICKDETAIL.Status <= '9'
               GROUP BY PICKDETAIL.LOC 
                     ,  PICKDETAIL.ID 
                     ,  PICKDETAIL.Status
                     ,  LLI.Qty
                     ,  PACK.CaseCnt ) T
         END                                                                                       --(Wan02)
      END

      --(Wan02) - START
      IF @c_AnalyticsType IN ('P-WIP', 'A-WIP')
      BEGIN
         SELECT @n_NoOfFPPTask = SUM(CASE WHEN TASKDETAIL.PickMethod = 'FP' AND TASKDETAIL.Status NOT IN ('S' ,'R', 'X') THEN 1 ELSE 0 END)
               ,@n_NoOfPPPTask = SUM(CASE WHEN TASKDETAIL.PickMethod = 'PP' AND TASKDETAIL.Status NOT IN ('S' ,'R', 'X') THEN 1 ELSE 0 END)
               ,@n_NoOfOPKTask = SUM(CASE WHEN TASKDETAIL.TaskType = 'OPK'  AND TASKDETAIL.Status NOT IN ('S' ,'R', 'X') THEN 1 ELSE 0 END)
               ,@n_NoOfPKTask  = SUM(CASE WHEN TASKDETAIL.TaskType = 'PK'   AND TASKDETAIL.Status NOT IN ('S' ,'R', 'X') THEN 1 ELSE 0 END)
               ,@n_NoOfComplPKTask = SUM(CASE WHEN TASKDETAIL.TaskType = 'PK' AND TASKDETAIL.Status = '9' 
                                              THEN 1 ELSE 0 END)
               ,@n_PerctgComplTask =(SUM(CASE WHEN TASKDETAIL.TaskType = 'PK' AND TASKDETAIL.Status = '9' 
                                              THEN 1 ELSE 0 END)
                                    /SUM(CASE WHEN TASKDETAIL.TaskType = 'PK' AND TASKDETAIL.Status NOT IN ('S' ,'R', 'X') THEN 1 ELSE 0 END)) * 100
               ,@n_NoOfExcpts      = SUM(CASE WHEN (TASKDETAIL.ReasonKey <> '' AND TASKDETAIL.Status NOT IN ('0','9','X')) OR
                                                   (TASKDETAIL.Status = '3' AND DATEDIFF(M, TASKDETAIL.EditDate, GETDATE()) > 20)  
                                              THEN 1 ELSE 0 END )        
         FROM TASKDETAIL WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (TASKDETAIL.FromLoc = LOC.Loc)
         LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
         WHERE TASKDETAIL.Loadkey = @c_Loadkey
         AND   ISNULL(RTRIM(AREADETAIL.Areakey),'') = @c_AreaKey
         
      END
      --(Wan02) - END

      UPDATE #Temp_pick WITH (ROWLOCK)
      SET TTLCases   = @n_TTLCases
         ,FullPallet = @n_FullPallet
         ,Cases      = @n_Cases
         ,Pieces     = @n_Pieces
         --(Wan02) - START
         ,OpenFP     = @n_OpenFP
         ,OpenPP     = @n_OpenPP
         ,OpenPC     = @n_OpenPC
         ,NoOfFPPTask     = @n_NoOfFPPTask    
         ,NoOfPPPTask     = @n_NoOfPPPTask    
         ,NoOfOPKTask     = @n_NoOfOPKTask    
         ,NoOfPKTask      = @n_NoOfPKTask     
         ,NoOfComplPKTask = @n_NoOfComplPKTask
         ,PerctgComplTask = @n_PerctgComplTask
         ,NoOfExcpts      = @n_NoOfExcpts      
         --(Wan02) - END
      WHERE Loadkey  = @c_Loadkey
      AND   Wavekey  = @c_Wavekey
      AND   Storerkey= @c_Storerkey
      AND   Section  = @c_Section
      AND   Areakey  = @c_AreaKey
      AND   Aisle    = @c_Aisle                                                                    --(Wan02)  
      
      FETCH NEXT FROM C_PickInfo INTO @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Section, @c_Areakey, @c_Aisle      --(Wan02)
   END
   CLOSE C_PickInfo
   DEALLOCATE C_PickInfo

   QUIT:
   --(Wan02) - START
   IF @c_AnalyticsType = '' AND @c_RptID = '01' GOTO QUIT_NOTRELEASE
   IF @c_AnalyticsType = 'P-WIP' AND @c_RptID = '01' GOTO QUIT_PLANNING
   IF @c_AnalyticsType = 'P-PLANNED' AND @c_RptID = '01' GOTO QUIT_PLANNING
   IF @c_AnalyticsType = 'P-UNPLAN' AND @c_RptID = '01' GOTO QUIT_PLANNING
   IF @c_AnalyticsType = 'A-WIP' AND @c_RptID IN ('01') GOTO QUIT_A_WIP

   IF @c_AnalyticsType = '' AND @c_RptID = '02' GOTO QUIT_NOTRELEASE_AREAPKGRAPH
   IF @c_AnalyticsType = 'P-PLANNED' AND @c_RptID = '02' GOTO QUIT_PLANING_PKGRAPH
   IF @c_AnalyticsType = 'P-UNPLAN' AND @c_RptID = '02' GOTO QUIT_PLANING_PKGRAPH
   IF @c_AnalyticsType = 'A-WIP' AND @c_RptID = '02-1' GOTO QUIT_A_WIP_HRGRAPH
   IF @c_AnalyticsType = 'A-WIP' AND @c_RptID = '02-2' GOTO QUIT_A_WIP_COMPLPKGRAPH

--   IF @c_RptID = '01' GOTO QUIT_RPTID_01 
--   IF @c_RptID = '02' GOTO QUIT_RPTID_02 

   QUIT_NOTRELEASE:
   --(Wan02) - END
      SELECT TotalOrders = SUM(TotalOrders) 
          ,  TotalPOs    = SUM(TotalPOs)
          ,  TotalShipTos= SUM(TotalShipTos)
          ,  TotalMarkFors=SUM(TotalMarkFors)
          ,  Section 
          ,  Areakey
          ,  NoOfLocs  = SUM(NoOfLocs)
          ,  TTLCases  = SUM(TTLCases)
          ,  FullPallet= SUM(FullPallet)
          ,  Cases = SUM(Cases)
          ,  Pieces= SUM(Pieces)
          ,  [Cube]  = SUM([Cube])
          ,  AvePalletCube
          ,  PalletsPOSPerLane
          ,  MinPerFPPick
          ,  MinPerCSPick
          ,  MinPerPCSPick
      FROM #Temp_pick
      GROUP BY Dockey
            ,  Section
            ,  AreaKey
            ,  AvePalletCube
            ,  PalletsPOSPerLane
            ,  MinPerFPPick
            ,  MinPerCSPick
            ,  MinPerPCSPick
      ORDER BY Dockey
            ,  Section
            ,  AreaKey
   --(Wan02) - START
      RETURN 
   QUIT_PLANNING:

      SELECT TotalLoads   
          ,  TotalOrders  
          ,  TotalPOs     
          ,  TotalShipTos 
          ,  TotalMarkFors 
          ,  TotalNotLoadOrders  
          ,  TotalNotLoadPOs 
          ,  Section 
          ,  Areakey
          ,  NoOfLocs  = SUM(NoOfLocs)
          ,  TTLCases  = SUM(TTLCases)
          ,  FullPallet= SUM(FullPallet)
          ,  Cases = SUM(Cases)
          ,  Pieces= SUM(Pieces)
          ,  OpenFP= SUM(OpenFP)
          ,  OpenPP= SUM(OpenPP)
          ,  OpenPC= SUM(OpenPC)
          ,  MaxPallet 
          ,  LaneUsed 
          ,  [Cube]  = SUM([Cube])
          ,  AvePalletCube
          ,  PalletsPOSPerLane
          ,  MinPerFPPick
          ,  MinPerCSPick
          ,  MinPerPCSPick 
      FROM #Temp_pick
      GROUP BY TotalLoads   
            ,  TotalOrders  
            ,  TotalPOs     
            ,  TotalShipTos 
            ,  TotalMarkFors 
            ,  TotalNotLoadOrders  
            ,  TotalNotLoadPOs 
            ,  Section
            ,  AreaKey
            ,  Aisle
            ,  MaxPallet 
            ,  LaneUsed
            ,  AvePalletCube
            ,  PalletsPOSPerLane
            ,  MinPerFPPick
            ,  MinPerCSPick
            ,  MinPerPCSPick
      ORDER BY Section
            ,  AreaKey
      RETURN 
   QUIT_A_WIP:
      SELECT TotalLoads  
          ,  TotalOrders 
          ,  TotalPOs    
          ,  TotalShipTos
          ,  TotalMarkFors
          ,  TotalNotLoadOrders
          ,  TotalNotLoadPOs
          ,  Section 
          ,  Areakey
          ,  Aisle
          ,  NoOfLocs  = SUM(NoOfLocs)
          ,  TTLCases  = SUM(TTLCases)
          ,  FullPallet= SUM(FullPallet)
          ,  Cases = SUM(Cases)
          ,  Pieces= SUM(Pieces)
          ,  OpenFP= SUM(OpenFP)
          ,  OpenPP= SUM(OpenPP)
          ,  OpenPC= SUM(OpenPC)
          ,  MaxPallet 
          ,  LaneUsed
          ,  [Cube]  = SUM([Cube])
          ,  AvePalletCube
          ,  PalletsPOSPerLane
          ,  MinPerFPPick
          ,  MinPerCSPick
          ,  MinPerPCSPick
          ,  NoOfFPPTask = SUM(NoOfFPPTask)
          ,  NoOfPPPTask = SUM(NoOfPPPTask)
          ,  NoOfOPKTask = SUM(NoOfOPKTask)
          ,  NoOfPKTask  = SUM(NoOfPKTask)
          ,  NoOfComplPKTask = SUM(NoOfComplPKTask)
          ,  PerctgComplTask = SUM(PerctgComplTask)
          ,  NoOfExcpts = SUM(NoOfExcpts)
      FROM #Temp_pick
      GROUP BY TotalLoads  
            ,  TotalOrders 
            ,  TotalPOs    
            ,  TotalShipTos
            ,  TotalMarkFors
            ,  TotalNotLoadOrders
            ,  TotalNotLoadPOs
            ,  Section
            ,  AreaKey
            ,  Aisle
            ,  MaxPallet
            ,  LaneUsed
            ,  AvePalletCube
            ,  PalletsPOSPerLane
            ,  MinPerFPPick
            ,  MinPerCSPick
            ,  MinPerPCSPick
      ORDER BY Section
            ,  AreaKey
            ,  Aisle
      RETURN
   QUIT_NOTRELEASE_AREAPKGRAPH:
   --(Wan02) - END
      SELECT Areakey, Type = '1Pieces' , Qty = SUM(Pieces) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '2Cases' , Qty = SUM(Cases) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '3# FPP' , Qty = SUM(FullPallet) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '4# of Locs' , Qty = SUM(NoOfLocs) 
      FROM #Temp_pick
      GROUP BY Areakey
      ORDER BY Areakey, Type
   --(Wan02) - START
      RETURN 
   QUIT_PLANING_PKGRAPH:
      SELECT Type = '# PL' , Qty = SUM(FullPallet) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Type = '# CS' , Qty = SUM(Cases) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Type = '# PC' , Qty = SUM(Pieces) 
      FROM #Temp_pick

      RETURN 
   QUIT_A_WIP_HRGRAPH:
      SELECT @n_UsedHRPerctg = (CONVERT(DECIMAL(15,2),TotalHR - RemainHR) / CASE WHEN TotalHR > 0 THEN TotalHR ELSE 1 END) * 100
            ,@n_RemainHRPerctg = (CONVERT(DECIMAL(15,2),RemainHR) / CASE WHEN TotalHR > 0 THEN TotalHR ELSE 1 END) * 100
      FROM (
            SELECT TotalHR = SUM((FullPallet * MinPerFPPick) + (Cases * MinPerCSPick) + (Pieces * MinPerPCSPick))
                 , RemainHR = SUM((OpenFP * MinPerFPPick) + (OpenPP * MinPerCSPick) + (OpenPC * MinPerPCSPick))
            FROM #Temp_pick
            ) Used

      SELECT Type = 'Used HR'
            ,@n_UsedHRPerctg
      UNION
      SELECT Type = 'Reamin HR'
            ,@n_RemainHRPerctg


      RETURN
   QUIT_A_WIP_COMPLPKGRAPH:
      SELECT Areakey, Qty = SUM(PerctgComplTask) 
      FROM #Temp_pick
      GROUP BY Areakey

      RETURN
                              
	/*                                
   CREATE TABLE #Temp_pick (
        Loadkey            NVARCHAR(10)       NOT NULL
      , Wavekey            NVARCHAR(10)       NOT NULL
      , Dockey             NVARCHAR(10)       NOT NULL
      , Storerkey          NVARCHAR(15)    NOT NULL
      , TotalOrders        INT            NULL
      , TotalPOs           INT            NULL
      , TotalShipTos       INT            NULL
      , TotalMarkFors      INT            NULL
      , Section            NVARCHAR(10)    NULL
      , Areakey            NVARCHAR(10)    NULL
      , NoOfLocs           INT            NULL
      , TTLCases           INT            NULL
      , FullPallet         INT            NULL     DEFAULT(0)
      , Cases              INT            NULL     DEFAULT(0)
      , Pieces             INT            NULL     DEFAULT(0)
      , [Cube]               FLOAT          NULL
      , AvePalletCube      FLOAT          NULL
      , PalletsPOSPerLane  FLOAT          NULL
      --(Wan01) - START
      , MinPerFPPick       FLOAT          NULL     DEFAULT(0.00)
      , MinPerCSPick       FLOAT          NULL     DEFAULT(0.00)
      , MinPerPCSPick      FLOAT          NULL     DEFAULT(0.00)
      --(Wan01) - END
       )
	
   IF @c_WaveKey = ''
   BEGIN
      INSERT INTO #Temp_pick
            ( LoadKey
            , Wavekey
            , DOCkey
            , Storerkey
            , TotalOrders
            , TotalPOs
            , TotalShipTos
            , TotalMarkFors
            , Section 
            , Areakey
            , NoOfLocs
            , TTLCases
            , [Cube]
            , AvePalletCube
            , PalletsPOSPerLane
            , MinPerFPPick
            , MinPerCSPick
            , MinPerPCSPick)
      SELECT LOADPLANDETAIL.LoadKey
            ,''
            ,LOADPLANDETAIL.LoadKey
            ,ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,COUNT(DISTINCT ORDERS.Orderkey)
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
            ,ISNULL(RTRIM(LOC.SectionKey),'') 
            ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
            ,COUNT(DISTINCT PICKDETAIL.LOC)
            ,FLOOR(ISNULL(SUM(CASE WHEN PACK.CaseCnt > 0 THEN PICKDETAIL.Qty / ISNULL(PACK.CaseCnt,0) ELSE 0 END),0))
            ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
            ,ISNULL(CLL.UDF01,0)
            ,ISNULL(CLL.UDF02,0)
            ,ISNULL(CLM.UDF01,0)
            ,ISNULL(CLM.UDF02,0)
            ,ISNULL(CLM.UDF03,0)
      FROM LOADPLANDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                              AND(PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
      LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
      LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')
                                          AND(ORDERS.Storerkey= CLL.Code) 
      LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick')
                                            AND(ORDERS.Storerkey= CLM.Storerkey) 
                                            AND(ORDERs.Facility = CLM.Code) 

      WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey
      GROUP BY LOADPLANDETAIL.LoadKey
              ,ISNULL(RTRIM(ORDERS.Storerkey),'')
              ,ISNULL(RTRIM(LOC.SectionKey),'') 
              ,ISNULL(RTRIM(AREADETAIL.Areakey),'')
              ,ISNULL(CLL.UDF01,0)
              ,ISNULL(CLL.UDF02,0)
              ,ISNULL(CLM.UDF01,0)
              ,ISNULL(CLM.UDF02,0)
              ,ISNULL(CLM.UDF03,0) 

   END
   ELSE
   BEGIN
      INSERT INTO #Temp_pick
            ( LoadKey
            , Wavekey
            , DOCkey
            , Storerkey
            , TotalOrders
            , TotalPOs
            , TotalShipTos
            , TotalMarkFors
            , Section 
            , Areakey
            , NoOfLocs
            , TTLCases
            , [Cube]
            , AvePalletCube
            , PalletsPOSPerLane
            , MinPerFPPick
            , MinPerCSPick
            , MinPerPCSPick)
      SELECT ''
            ,WAVEDETAIL.Wavekey
            ,WAVEDETAIL.Wavekey
            ,ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,COUNT(DISTINCT ORDERS.Orderkey)
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.Consigneekey),'')) 
            ,COUNT(DISTINCT ISNULL(RTRIM(ORDERS.MarkForKey),''))
            ,ISNULL(RTRIM(LOC.SectionKey),'') 
            ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
            ,COUNT(DISTINCT PICKDETAIL.LOC)
            ,FLOOR(ISNULL(SUM(CASE WHEN PACK.CaseCnt > 0 THEN PICKDETAIL.Qty / ISNULL(PACK.CaseCnt,0) ELSE 0 END),0))
            ,ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00) 
            ,ISNULL(CLL.UDF01,0)
            ,ISNULL(CLL.UDF02,0)
            ,ISNULL(CLM.UDF01,0)
            ,ISNULL(CLM.UDF02,0)
            ,ISNULL(CLM.UDF03,0)
      FROM WAVEDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU  WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                              AND(PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
      LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
      LEFT JOIN CODELKUP CLL WITH (NOLOCK) ON (CLL.ListName = 'PLPerLane')
                                          AND(ORDERS.Storerkey= CLL.Code) 
      LEFT JOIN CODELKUP CLM WITH (NOLOCK) ON (CLM.ListName = 'MinPerPick')
                                            AND(ORDERS.Storerkey= CLM.Storerkey) 
                                            AND(ORDERs.Facility = CLM.Code) 

      WHERE WAVEDETAIL.WaveKey = @c_Wavekey
      GROUP BY ORDERS.LoadKey
              ,WAVEDETAIL.Wavekey
              ,ISNULL(RTRIM(ORDERS.Storerkey),'')
              ,ISNULL(RTRIM(LOC.SectionKey),'') 
              ,ISNULL(RTRIM(AREADETAIL.Areakey),'') 
              ,ISNULL(CLL.UDF01,0)
              ,ISNULL(CLL.UDF02,0)
              ,ISNULL(CLM.UDF01,0)
              ,ISNULL(CLM.UDF02,0)
              ,ISNULL(CLM.UDF03,0)

   END

   DECLARE C_PickInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT 
          Loadkey
         ,Wavekey
         ,Storerkey
         ,Section    
         ,AreaKey
   FROM #Temp_pick

   OPEN C_PickInfo  
   FETCH NEXT FROM C_PickInfo INTO @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Section, @c_Areakey  

   WHILE (@@FETCH_STATUS<>-1)  
   BEGIN  
      IF EXISTS ( SELECT 1   
                  FROM STORERCONFIG SC WITH (NOLOCK) 
                  WHERE SC.Storerkey = @c_Storerkey
                  AND   SC.Configkey = 'PrePackByBOM'   
                  AND   SC.SValue = '1' ) AND
         EXISTS ( SELECT 1   
                  FROM STORERCONFIG SC WITH (NOLOCK) 
                  WHERE SC.Storerkey = @c_Storerkey  
                  AND   SC.Configkey = 'PrePackConsoAllocation'   
                  AND   SC.SValue = '1' )
      BEGIN

         EXEC isp_GetPPKPltCase2 
              @c_LoadKey
            , ''  
            , '' 
            , @n_Cases        OUTPUT 
            , @n_FullPallet   OUTPUT  
            , @n_Pieces       OUTPUT   
            ,''  
            ,''  
            ,'N' --@c_Picks 
            ,'Y' --@c_GetTotPallet
            ,@c_Storerkey
            ,@c_Wavekey
            ,@c_Section                                                                   
            ,@c_Areakey

         EXEC isp_GetPPKPltCase2 
              @c_LoadKey
            , ''  
            , '' 
            , @n_TTLCases     OUTPUT 
            , 0 
            , 0   
            ,''  
            ,''  
            ,'N' --@c_Picks  
            ,'N' --@c_GetTotPallet
            ,@c_Storerkey
            ,@c_Wavekey
            ,@c_Section                                                                   
            ,@c_Areakey

         UPDATE #Temp_pick WITH (ROWLOCK)
         SET TTLCases= @n_TTLCases
         WHERE Loadkey  = @c_Loadkey
         AND   Wavekey  = @c_Wavekey
         AND   Storerkey= @c_Storerkey
         AND   Section  = @c_Section
         AND   Areakey  = @c_AreaKey
      END
      ELSE
      BEGIN
         SELECT @n_FullPallet = ISNULL(SUM(FP),0)
               ,@n_Cases = FLOOR(ISNULL(SUM(CS),0))  
               ,@n_Pieces= SUM(PCS)
         FROM (
            SELECT FP = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 1 ELSE 0 END 
                  ,CS = CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0 ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END END               
                  ,PCS= CASE WHEN SUM(PICKDETAIL.Qty) = LLI.Qty THEN 0 ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty) % CONVERT(NUMERIC,ISNULL(PACK.CaseCnt,0))ELSE SUM(PICKDETAIL.Qty) END END
            FROM ORDERS WITH (NOLOCK)
            JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey) 
            JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey) AND (PICKDETAIL.SKU = SKU.SKU)
            JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            JOIN LOC  WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
            JOIN ( SELECT Loc
                        , Id
                        , Qty = SUM (Qty)
                   FROM LOTxLOCxID WITH (NOLOCK) 
                   WHERE Storerkey = @c_Storerkey 
                   GROUP BY Loc
                           ,Id ) LLI ON (PICKDETAIL.Loc= LLI.Loc)
                                     AND(PICKDETAIL.Id = LLI.Id)
            LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.Putawayzone = AREADETAIL.Putawayzone)
            WHERE ORDERS.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN ORDERS.Loadkey ELSE  @c_LoadKey END
            AND   ORDERS.UserDefine09 = CASE WHEN ISNULL(@c_Wavekey ,'')='' THEN ORDERS.UserDefine09 ELSE @c_Wavekey END
            AND   ORDERS.Storerkey = @c_Storerkey
            AND   LOC.Sectionkey = @c_Section
            AND   ISNULL(RTRIM(AREADETAIL.Areakey),'') = @c_AreaKey
            GROUP BY PICKDETAIL.LOC 
                  ,  PICKDETAIL.ID 
                  ,  LLI.Qty
                  ,  PACK.CaseCnt ) T
      END

      UPDATE #Temp_pick WITH (ROWLOCK)
      SET FullPallet = @n_FullPallet
         ,Cases = @n_Cases
         ,Pieces= @n_Pieces
      WHERE Loadkey  = @c_Loadkey
      AND   Wavekey  = @c_Wavekey
      AND   Storerkey= @c_Storerkey
      AND   Section  = @c_Section
      AND   Areakey  = @c_AreaKey
      
      FETCH NEXT FROM C_PickInfo INTO @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Section, @c_Areakey
   END
   CLOSE C_PickInfo
   DEALLOCATE C_PickInfo

   IF @c_RptID = '01' GOTO QUIT_RPTID_01
   IF @c_RptID = '02' GOTO QUIT_RPTID_02

   QUIT_RPTID_01:
      SELECT TotalOrders = SUM(TotalOrders) 
          ,  TotalPOs    = SUM(TotalPOs)
          ,  TotalShipTos= SUM(TotalShipTos)
          ,  TotalMarkFors=SUM(TotalMarkFors)
          ,  Section 
          ,  Areakey
          ,  NoOfLocs  = SUM(NoOfLocs)
          ,  TTLCases  = SUM(TTLCases)
          ,  FullPallet= SUM(FullPallet)
          ,  Cases = SUM(Cases)
          ,  Pieces= SUM(Pieces)
          ,  [Cube]  = SUM([Cube])
          ,  AvePalletCube
          ,  PalletsPOSPerLane
          ,  MinPerFPPick
          ,  MinPerCSPick
          ,  MinPerPCSPick
      FROM #Temp_pick
      GROUP BY Dockey
            ,  Section
            ,  AreaKey
            ,  AvePalletCube
            ,  PalletsPOSPerLane
            ,  MinPerFPPick
            ,  MinPerCSPick
            ,  MinPerPCSPick
      ORDER BY Dockey
            ,  Section
            ,  AreaKey

      RETURN 

   QUIT_RPTID_02:
      SELECT Areakey, Type = '1Pieces' , Qty = SUM(Pieces) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '2Cases' , Qty = SUM(Cases) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '3# FPP' , Qty = SUM(FullPallet) 
      FROM #Temp_pick
      GROUP BY Areakey
      UNION
      SELECT Areakey, Type = '4# of Locs' , Qty = SUM(NoOfLocs) 
      FROM #Temp_pick
      GROUP BY Areakey
      ORDER BY Areakey, Type
*/  
   --(Wan02) - END                             
    
END

GO