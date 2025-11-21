SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: fnc_GetDespatchLaneDashBoard                        */  
/* Creation Date: 21-JAN-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#266625: WMS Despatch Lane DashBoard                      */  
/*                                                                       */  
/* Called By: Call from Despatch Lane DashBoard                          */
/*                      datawindow - d_dw_despatch_Lane_dashboard        */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  
CREATE FUNCTION [dbo].[fnc_GetDespatchLaneDashBoard] (@c_Storerkey  NVARCHAR(15), @c_Facility NVARCHAR(5))  
RETURNS @tDespatchLane TABLE   
(           
    RouteID          NVARCHAR(30)  NOT NULL
   ,Wavekey          NVARCHAR(10)  NOT NULL
   ,TotalQtyCube     NVARCHAR(25)  NOT NULL
   ,TotalCarton      NVARCHAR(10)  NOT NULL
   ,RemainingCarton  NVARCHAR(10)  NOT NULL
   ,Loc              NVARCHAR(30)  NOT NULL
   ,LaneTruck        NVARCHAR(25)  NOT NULL
 )  
AS  
BEGIN
--   SET NOCOUNT ON   
--   SET QUOTED_IDENTIFIER OFF   
--   SET ANSI_NULLS OFF   
--   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @n_SeqNo           INT
         , @n_Qty             INT
         , @n_Cube            FLOAT
         , @n_TotalQty        INT
         , @n_TotalCube       FLOAT
         , @n_PackedCarton    INT
         , @n_TotalCarton     INT

         , @c_Facility_ORD    NVARCHAR(5)
         , @c_Storerkey_ORD   NVARCHAR(15)
         , @c_C_City          NVARCHAR(45)
         , @c_RouteID         NVARCHAR(30)
         , @c_Wavekey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_TotalCarton     NVARCHAR(10)

         , @c_PrevRouteID     NVARCHAR(30)
         , @c_PrevWavekey     NVARCHAR(10)

   SET @n_SeqNo         = 1
   SET @n_Qty           = 0
   SET @n_Cube          = 0
   SET @n_TotalQty      = 0
   SET @n_TotalCube     = 0.00
   SET @n_PackedCarton  = 0
   SET @n_TotalCarton   = 0

   SET @c_Facility_ORD  = ''
   SET @c_Storerkey_ORD = ''
   SET @c_C_City        = ''
   SET @c_RouteID       = ''
   SET @c_Wavekey       = ''
   SET @c_Orderkey      = ''
   SET @c_PickSlipNo    = ''
   SET @c_TotalCarton   = ''
   
   SET @c_PrevRouteID   = ''
   SET @c_PrevWavekey   = ''

   DECLARE @tHdr TABLE
      (
         SeqNo       INT   NOT NULL
      ,  Facility    NVARCHAR(5)  
      ,  Storerkey   NVARCHAR(15)
      ,  RouteID     NVARCHAR(30)
      ,  WaveKey     NVARCHAR(10)
      ,  TotalQty    INT
      ,  TotalCube   FLOAT
      ,  TotalCarton NVARCHAR(10)
      )

   DECLARE @tDet TABLE
      (  SeqNo       INT   NOT NULL
      ,  Loc         NVARCHAR(10) 
      ,  InStageLoc  INT
      ,  ScanToDoor  INT
      )

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT
          Facility_ORD = ISNULL(RTRIM(ORDERS.Facility),'')
         ,Storerkey_ORD= ISNULL(RTRIM(ORDERS.Storerkey),'')
         ,C_City  = ISNULL(RTRIM(ORDERS.C_City),'')
         ,RouteID = ISNULL(RTRIM(CODELKUP.Short),'')
         ,WaveKey = WAVEDETAIL.WaveKey
         ,Orderkey= ORDERS.Orderkey
   FROM ORDERS     WITH (NOLOCK)
   JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey)
   JOIN CODELKUP   WITH (NOLOCK) ON (CODELKUP.ListName = 'VFROUTE')
                                 AND(ORDERS.C_City = CODELKUP.Code)
   WHERE ORDERS.Status < '9'
   AND   ORDERS.Facility = CASE WHEN @c_Facility = 'ALL' THEN ORDERS.Facility ELSE @c_Facility END
   AND   ORDERS.Storerkey= CASE WHEN @c_Storerkey= 'ALL' THEN ORDERS.Storerkey ELSE @c_Storerkey END
   ORDER BY ISNULL(RTRIM(CODELKUP.Short),'')
        ,   WAVEDETAIL.WaveKey
   OPEN CUR_ORD      
         
   FETCH NEXT FROM CUR_ORD INTO @c_Facility_ORD 
                              , @c_Storerkey_ORD  
                              , @c_C_City  
                              , @c_RouteID
                              , @c_Wavekey
                              , @c_Orderkey 
                               
   WHILE @@FETCH_STATUS <> -1      
   BEGIN 
      SET @n_Qty          = 0
      SET @n_Cube         = 0
      SET @n_PackedCarton = NULL
      SET @c_PickSlipNo   = ''

      SELECT @n_Qty = SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked)
            ,@n_Cube= SUM(SKU.StdCube * (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked))
      FROM ORDERS      WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                     AND(ORDERDETAIL.Sku = SKU.Sku)
      WHERE ORDERS.Orderkey = @c_Orderkey
      AND   ORDERS.Userdefine09 = @c_Wavekey

      SET @n_TotalQty = @n_TotalQty + @n_Qty
      SET @n_TotalCube= @n_TotalCube+ @n_Cube

      SELECT @c_PickSlipNo = PACKHEADER.PickSlipNo
           , @n_PackedCarton = CASE WHEN PACKHEADER.Status = '9' THEN COUNT( DISTINCT CartonNo) ELSE NULL END
      FROM PICKHEADER WITH (NOLOCK)
      JOIN PACKHEADER WITH (NOLOCK) ON (PICKHEADER.PickHeaderKey = PACKHEADER.PickSlipNo)
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
      WHERE PICKHEADER.Orderkey = @c_Orderkey
      AND   PICKHEADER.Wavekey  = @c_Wavekey
      GROUP BY PACKHEADER.PickSlipNo
            ,  PACKHEADER.Status

      IF @c_TotalCarton = '' AND @n_PackedCarton IS NOT NULL
      BEGIN
         SET @n_TotalCarton = @n_TotalCarton + @n_PackedCarton
      END
      ELSE
      BEGIN
         SET @c_TotalCarton = 'PENDING' 
      END
      

      INSERT INTO @tDet (SeqNo, Loc, InStageLoc, ScanToDoor)
      SELECT  @n_SeqNo
            , DROPID.DropLoc
--            , InStageLoc = CASE WHEN DROPID.Status < '9' AND ISNULL(RTRIM(DROPID.AdditionalLoc),'') = '' THEN COUNT(DISTINCT DROPIDDETAIL.ChildID) ELSE 0 END
--            , ScanToDoor = CASE WHEN DROPID.Status = '9' AND ISNULL(RTRIM(DROPID.AdditionalLoc),'') <>'' THEN COUNT(DISTINCT DROPIDDETAIL.ChildID) ELSE 0 END
            , InStageLoc = COUNT(DISTINCT CASE WHEN ISNULL(STT.RowRef,0) = 0  AND ISNULL(RTRIM(DROPID.AdditionalLoc),'') = '' THEN DROPIDDETAIL.ChildID ELSE NULL END )
            , ScanToDoor = COUNT(DISTINCT STT.URNNo )
      FROM PACKDETAIL   WITH (NOLOCK)
      JOIN DROPIDDETAIL WITH (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.ChildID)
      JOIN DROPID       WITH (NOLOCK) ON (DROPID.DROPID = DROPIDDETAIL.DROPID)
      JOIN LOC          WITH (NOLOCK) ON (DROPID.DropLoc = LOC.Loc) 
                                      AND(LOC.LocationCategory = 'STAGING')
      LEFT JOIN RDT.rdtScanToTruck STT WITH (NOLOCK) ON (DROPIDDETAIL.ChildID = STT.URNNo)
      WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo
      AND   LOC.Facility = @c_Facility_ORD
      GROUP BY DROPID.DropLoc
            ,  DROPID.Status
            ,  ISNULL(RTRIM(DROPID.AdditionalLoc),'') 
      
      SET @c_PrevRouteID = @c_RouteID 
      SET @c_PrevWavekey = @c_Wavekey

      FETCH NEXT FROM CUR_ORD INTO @c_Facility_ORD 
                                 , @c_Storerkey_ORD
                                 , @c_C_City    
                                 , @c_RouteID
                                 , @c_Wavekey
                                 , @c_Orderkey      

      IF @c_RouteID <> @c_PrevRouteID OR @c_Wavekey <> @c_PrevWavekey OR @@FETCH_STATUS = -1
      BEGIN

         IF @c_TotalCarton = ''
         BEGIN
            SET @c_TotalCarton = CONVERT(NVARCHAR(10), @n_TotalCarton)
         END 

         INSERT INTO @tHdr (SeqNo, Facility, Storerkey, RouteID, WaveKey, TotalQty, TotalCube, TotalCarton)
         VALUES (@n_SeqNo, @c_Facility_ORD, @c_Storerkey_ORD, @c_PrevRouteID, @c_PrevWavekey, @n_TotalQty, @n_TotalCube, @c_TotalCarton)

         SET @n_SeqNo = @n_SeqNo + 1
         SET @n_TotalQty    = 0
         SET @n_TotalCube   = 0.00
         SET @n_TotalCarton = 0
         SET @c_TotalCarton = ''
      END
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   INSERT INTO @tDespatchLane   
   (           
       RouteID        
      ,Wavekey        
      ,TotalQtyCube       
      ,TotalCarton  
      ,RemainingCarton  
      ,Loc            
      ,LaneTruck    
   )
   SELECT HDR.RouteID
         ,HDR.WaveKey
         ,CONVERT(NVARCHAR(10),HDR.TotalQty) + '/' + CONVERT(NVARCHAR(10), HDR.TotalCube)
         ,CONVERT(NVARCHAR(10),HDR.TotalCarton) 
         ,RemainingCarton =CASE WHEN HDR.TotalCarton = 'PENDING' THEN 'PENDING'
                                 ELSE CONVERT( VARCHAR(10), CONVERT(INT, HDR.TotalCarton)
                                      - (SELECT ISNULL(SUM(InStageLoc + ScanToDoor),0)
                                         FROM @tDet DET
                                         WHERE SeqNo = HDR.SeqNo
                                         ))
                                 END
         ,Loc = CONVERT( NCHAR(10), ISNULL(RTRIM(Loc.Loc),'')) + ' (Lane/Truck)'
         ,LaneTruck = CONVERT(VARCHAR(10), ISNULL(SUM(DET.InStageLoc),0)) + '/' + CONVERT(NVARCHAR(10),ISNULL(SUM(DET.ScanToDoor),0))
   FROM LOC WITH (NOLOCK)
   JOIN @tHdr HDR ON (HDR.Facility = LOC.Facility)
   LEFT OUTER JOIN @tDet DET ON (HDR.SeqNo = DET.SeqNo) AND (Loc.Loc = DET.Loc)
   WHERE LOC.Facility = CASE WHEN @c_Facility = 'ALL' THEN LOC.Facility ELSE @c_Facility END
   AND   LOC.LocationCategory = 'STAGING'
   GROUP BY HDR.SeqNo
         ,  HDR.RouteID
         ,  HDR.WaveKey
         ,  CONVERT(NVARCHAR(10),HDR.TotalQty) 
         ,  CONVERT(NVARCHAR(10),HDR.TotalCube)
         ,  CONVERT(NVARCHAR(10),HDR.TotalCarton) 
         ,  ISNULL(RTRIM(Loc.Loc),'')
   ORDER BY HDR.SeqNo
         ,  ISNULL(RTRIM(Loc.Loc),'')

   RETURN 
END

GO