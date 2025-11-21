SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_PTL                                          */
/* Creation Date: 2021-07-09                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-09  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/* 2021-10-26  Wan01    1.1   CR 2.7 Change FAILPTL flag to InvoiceNo   */
/* 2022-04-26  Wan02    1.2   WMS-19522 - RG - Adidas SEA - Release Wave*/
/*                            on DP Loc Sequence                        */
/* 2022-12-02  Wan03    1.3   Fixed Blocking                            */
/************************************************************************/

CREATE PROC [dbo].[ispRLWAV43_PTL]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_Debug       INT            = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1
         
         , @n_NoOfPTLLoc            INT   = 0
         , @n_NoOfLargeLoc          INT   = 0
         , @n_NofOfMultiOrder       INT   = 0
         , @n_NoOfLargeVolOrd       INT   = 0
         
         , @n_RowID_SortStation     INT   = 0
         , @n_RowID_SortLoc         INT   = 0
         , @n_FitOrderVolume        INT   = 0
         , @n_CubicCapacity         FLOAT = 0.00
         , @n_CubicCapacity_Max     FLOAT = 0.00 
         
         , @c_Storerkey             NVARCHAR(15) = ''
         , @c_Style                 NVARCHAR(20) = ''                
         , @c_SortStationGroups     NVARCHAR(110)= ''
         , @c_SortStation           NVARCHAR(10) = ''
         , @c_PTLLoc                NVARCHAR(10) = ''
         , @c_Orderkey              NVARCHAR(10) = ''
         , @c_TaskBatchNo           NVARCHAR(10) = ''    
         , @c_PickZone              NVARCHAR(10) = '' 
         
         , @c_PickdetailKey         NVARCHAR(10) = ''             --(Wan03)
         
         , @CUR_UPD                 CURSOR                        --(Wan03)         
         , @CUR_PTSK                CURSOR                        --(Wan03)  
           
   DECLARE @t_SortLocCubic          TABLE
         ( RowID                    INT            IDENTITY(1,1)           PRIMARY KEY
         , Loc                      NVARCHAR(10)   NOT NULL DEFAULT('')
         , LogicalLocation          NVARCHAR(10)   NOT NULL DEFAULT('')
         , DevicePosition           NVARCHAR(10)   NOT NULL DEFAULT('')  
         , LogicalName              NVARCHAR(10)   NOT NULL DEFAULT('')   
         , SortStationGroup         NVARCHAR(10)   NOT NULL DEFAULT('')          
         , SortStation              NVARCHAR(10)   NOT NULL DEFAULT('') 
         , CubicCapacity_PR         FLOAT          NOT NULL DEFAULT(0.00)
         , CubicCapacity            FLOAT          NOT NULL DEFAULT(0.00)
         , MaxCubicCapacity         FLOAT          NOT NULL DEFAULT(0.00) 
         , Orderkey                 NVARCHAR(10)   NOT NULL DEFAULT('')  
         )
         
   DECLARE @t_PTLAsgmtWIP           TABLE
         ( RowID                    INT            IDENTITY(1,1)           PRIMARY KEY
         , SortStation              NVARCHAR(10)   NOT NULL DEFAULT('') 
         , Loc                      NVARCHAR(10)   NOT NULL DEFAULT('')
         , LogicalLocation          NVARCHAR(10)   NOT NULL DEFAULT('')
         , CubicCapacity_PR         FLOAT          NOT NULL DEFAULT(0.00)
         , CubicCapacity            FLOAT          NOT NULL DEFAULT(0.00)
         , MaxCubicCapacity         FLOAT          NOT NULL DEFAULT(0.00) 
         , NoOfEmptyLoc             INT            NOT NULL DEFAULT(0)
         , FitOrderVolume           INT            NOT NULL DEFAULT(1)
         )      
   
   DECLARE @t_MultiOrder            TABLE
         ( RowID                    INT            IDENTITY(1,1)           PRIMARY KEY
         , Orderkey                 NVARCHAR(10)   NOT NULL DEFAULT('')  
         , Storerkey                NVARCHAR(20)   NOT NULL DEFAULT('')  
         , Sku                      NVARCHAR(20)   NOT NULL DEFAULT('') 
         , Style                    NVARCHAR(20)   NOT NULL DEFAULT('') 
         , Qty                      INT            NOT NULL DEFAULT(0)                               
         , Volume                   FLOAT          NOT NULL DEFAULT(0.00)
         , Ord_Volume               FLOAT          NOT NULL DEFAULT(0.00)
         , SortStationGroups        NVARCHAR(110)  NOT NULL DEFAULT('')
         , SortStation              NVARCHAR(10)   NOT NULL DEFAULT('') 
         , PTLLoc                   NVARCHAR(10)   NOT NULL DEFAULT('') 
         ) 
       
   SET @b_Success  = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  

   INSERT INTO @t_MultiOrder ( Orderkey, Storerkey, Sku, Style, Qty, Volume, SortStationGroups )
   SELECT o.OrderKey, p.Storerkey, p.Sku, s.Style, Qty = SUM(p.Qty), Volume = SUM(p.Qty * s.STDCUBE)
        , SortStationGroups = ISNULL(w.UserDefine01,'') + ',' + ISNULL(w.UserDefine02,'') + ',' --CR v2.5
                            + ISNULL(w.UserDefine03,'') + ',' + ISNULL(w.UserDefine04,'') + ','
                            + ISNULL(w.UserDefine05,'')
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
   JOIN dbo.Sku AS s WITH (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
   WHERE w.WaveKey = @c_Wavekey
   AND o.ECOM_SINGLE_Flag = 'M'
   GROUP BY o.OrderKey, p.Storerkey, p.Sku, s.Style
         ,  ISNULL(w.UserDefine01,''), ISNULL(w.UserDefine02,''), ISNULL(w.UserDefine03,'')
         ,  ISNULL(w.UserDefine04,'') ,ISNULL(w.UserDefine05,'')
   ORDER BY 3 DESC
          , 2  
          , 1
  
   IF @@ROWCOUNT = 0
   BEGIN
      GOTO QUIT_SP
   END
   
   ;WITH ORD_VOL ( Orderkey, volume ) AS 
   (  SELECT tmo.Orderkey, SUM(tmo.volume)
      FROM @t_MultiOrder tmo
      GROUP BY tmo.Orderkey
   )
   UPDATE tmo
      SET ORD_Volume = ov.volume
   FROM @t_MultiOrder tmo
   JOIN ORD_VOL AS ov ON ov.Orderkey = tmo.Orderkey
                    
   SELECT TOP 1 @c_Storerkey = tmo.Storerkey
         , @c_SortStationGroups = tmo.SortStationGroups
   FROM @t_MultiOrder AS tmo
   
   --GET SortStationGroup's Loc 
   ; WITH SSLOC (loc, LogicalLocation, DevicePosition, LogicalName, PickZone, CubicCapacity, SortStation) AS
   (  SELECT l.Loc, l.LogicalLocation, dp.DevicePosition, dp.LogicalName, l.PickZone, l.CubicCapacity, dp.DeviceID
      FROM dbo.DeviceProfile AS dp WITH (NOLOCK) 
      JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = dp.Loc
      WHERE dp.StorerKey = @c_Storerkey
      AND  l.LocationCategory = 'PTL'
      AND  l.LocationType = 'OTHER'        
      AND  l.LocationFlag = 'HOLD'  
      AND  dp.LogicalName <> 'PACK'             --CR 4.0   
   )

   INSERT INTO @t_SortLocCubic (Loc, LogicalLocation, DevicePosition, LogicalName, SortStationGroup, SortStation, CubicCapacity_PR, CubicCapacity)
   SELECT l.Loc, l.LogicalLocation, l.DevicePosition, l.LogicalName, l.PickZone, l.SortStation
        , CubicCapacity_PR = LAG( l.CubicCapacity, 1, 0 ) OVER (ORDER BY l.SortStation, l.CubicCapacity)
        , l.CubicCapacity
   FROM STRING_SPLIT(@c_SortStationGroups, ',') AS ss
   JOIN SSLOC AS l WITH (NOLOCK) ON LTRIM(RTRIM(ss.[value])) = l.PickZone  
   WHERE ss.[value] <> ''
   ORDER BY l.SortStation, l.CubicCapacity

   --GET SortStation's Cubic Capacity & Max Cubic Capacity
   ; WITH SS (SortStation, MAXCubicCapacity) AS
   (  
      SELECT tslc.SortStation, MAXCubicCapacity = MAX(tslc.CubicCapacity)
      FROM @t_SortLocCubic AS tslc
      GROUP BY tslc.SortStation
   )

   UPDATE tslc
   SET   MaxCubicCapacity = s.MAXCubicCapacity
   FROM @t_SortLocCubic AS tslc
   JOIN SS AS s ON s.SortStation = tslc.SortStation
   
   ------------------------------------------------------
   -- Clear Orders Fail Indicator on Previous run - START
   ------------------------------------------------------ 
   UPDATE o WITH (ROWLOCK)
   SET   InvoiceNo = ''                --Wan01
      ,  EditWho = SUSER_SNAME()
      ,  EditDate= GETDATE()
      ,  TrafficCop = NULL
   FROM dbo.ORDERS AS o
   WHERE o.InvoiceNo = 'FAILPTL'       --Wan01
   AND EXISTS (SELECT 1 FROM @t_MultiOrder AS tmo 
               WHERE tmo.PTLLoc = ''
               AND tmo.Orderkey = o.OrderKey
               )

   IF @@ERROR <> 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 62010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update ORDERS Fail - Clear Userdefine01. (ispRLWAV43_PTL)'
      GOTO QUIT_SP
   END
   
   ------------------------------------------------------
   -- Clear Orders Fail Indicator on Previous run - END
   ------------------------------------------------------ 
   IF @b_Debug = 1
   BEGIN
      SELECT *
      FROM @t_SortLocCubic AS tslc
   
      SELECT  tmo.Orderkey 
            ,  tmo.Ord_Volume
            , CASE WHEN tmo.Ord_Volume > @n_CubicCapacity_Max THEN tmo.Orderkey ELSE NULL END
      FROM @t_MultiOrder AS tmo 
         ORDER BY orderkey
      
      SELECT  COUNT(DISTINCT tmo.Orderkey )
            , COUNT (DISTINCT CASE WHEN tmo.Ord_Volume > @n_CubicCapacity_Max THEN tmo.Orderkey ELSE NULL END)
      FROM @t_MultiOrder AS tmo 
   END
      
   ------------------------------------------
   -- Pre PTL Assignment Check - START
   ------------------------------------------
   SELECT @n_NoOfPTLLoc   = COUNT(1) 
         ,@n_NoOfLargeLoc = ISNULL(SUM(CASE WHEN tslc.CubicCapacity = 0 THEN 1 ELSE 0 END),0)
         ,@n_CubicCapacity_Max = ISNULL(MAX(tslc.CubicCapacity),0)
   FROM @t_SortLocCubic AS tslc
   
   SELECT @n_NofOfMultiOrder = COUNT(DISTINCT tmo.Orderkey)  
         ,@n_NoOfLargeVolOrd = COUNT(DISTINCT CASE WHEN tmo.Ord_Volume > @n_CubicCapacity_Max THEN tmo.Orderkey ELSE NULL END)
   FROM @t_MultiOrder AS tmo 

   IF @b_Debug = 1
   BEGIN
      SELECT 'TEST', @n_NoOfLargeLoc '@n_NoOfLargeLoc', @n_NoOfLargeVolOrd '@n_NoOfLargeVolOrd', @n_CubicCapacity_Max '@n_CubicCapacity_Max'
         , @n_NofOfMultiOrder'@n_NofOfMultiOrder', @n_NoOfPTLLoc '@n_NoOfPTLLoc' 
   END
   
   IF @n_NoOfPTLLoc < @n_NofOfMultiOrder --@n_NoOfLargeLoc < @n_NoOfLargeVolOrd OR @n_NoOfPTLLoc < @n_NofOfMultiOrder
   BEGIN

      --(Wan02) - START - Rollback TMReleaseFlag to 'N' and save PTLFAIL
      --WHILE @@TRANCOUNT > 0 
      --BEGIN
      --   COMMIT TRAN
      --END
      
      IF @@TRANCOUNT > 0 
      BEGIN 
         ROLLBACK TRAN
      END 
      --(Wan02) - END
      
      ; WITH UPDORD ( OrderKey ) AS       --Wan01 
      ( SELECT TOP (@n_NoOfLargeVolOrd - @n_NoOfLargeLoc) tmo.Orderkey 
        FROM @t_MultiOrder AS tmo
        WHERE tmo.Volume > @n_CubicCapacity_Max   
        GROUP BY tmo.Orderkey 
      )
 
      UPDATE o WITH (ROWLOCK)
      SET   InvoiceNo = 'FAILPTL'         --Wan01
         ,  EditWho = SUSER_SNAME()
         ,  EditDate= GETDATE()
         ,  TrafficCop = NULL
      FROM UPDORD uo                      --Wan01 
      JOIN ORDERS o ON o.Orderkey = uo.Orderkey
         
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 62020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update ORDERS Fail - Insufficient Large Loc. (ispRLWAV43_PTL)'
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT < @n_StartTCnt 
      BEGIN
         BEGIN TRAN
      END
         
      SET @n_Continue = 3
      SET @n_Err = 62020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insufficient PTL Loc for Multi Orders. (ispRLWAV43_PTL)'
      GOTO QUIT_SP   
   END
   ------------------------------------------
   -- Pre PTL Assignment Check - END
   ------------------------------------------  
   
   ------------------------------------------
   -- PTL Assignment - START
   ------------------------------------------  
   WHILE 1 = 1
   BEGIN
      SELECT TOP 1 @c_Style = tmo.Style
      FROM @t_MultiOrder AS tmo
      WHERE tmo.PTLLoc = ''
      GROUP BY tmo.Style, tmo.Qty
      ORDER BY tmo.Qty DESC, tmo.Style
      
      IF @@ROWCOUNT= 0 
      BEGIN
         BREAK
      END
      
      DELETE FROM @t_PTLAsgmtWIP

      ;WITH SS1 (SortStation, TotalEmptyLoc) AS
      ( SELECT tslc.SortStation, TotalEmptyLoc = COUNT(DISTINCT tslc.Loc)
        FROM @t_SortLocCubic AS tslc
        WHERE tslc.Orderkey = ''
        GROUP BY tslc.SortStation
      )
      
      INSERT INTO @t_PTLAsgmtWIP ( SortStation, CubicCapacity, MaxCubicCapacity, Loc, LogicalLocation, FitOrderVolume )
      SELECT tslc.SortStation 
            ,CubicCapacity = tslc.CubicCapacity
            ,MaxCubicCapacity = tslc.MaxCubicCapacity 
            ,tslc.Loc
            ,tslc.LogicalLocation
            ,FitOrderVolume = 1
      FROM SS1
      JOIN @t_SortLocCubic AS tslc ON tslc.SortStation = SS1.SortStation
      WHERE tslc.Orderkey = ''
      ORDER BY SS1.TotalEmptyLoc DESC
               , tslc.SortStation
               , tslc.CubicCapacity
               , tslc.LogicalLocation 

      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END
  
      SET @n_RowID_SortStation = 0
      WHILE 1 = 1 -- PTL SortStation
      BEGIN
         SET @n_FitOrderVolume = 1
         SELECT TOP 1 
                @c_SortStation = tpaw.SortStation
               ,@n_RowID_SortStation = MAX(tpaw.RowID)
         FROM @t_PTLAsgmtWIP AS tpaw
         WHERE tpaw.RowID > @n_RowID_SortStation
         AND tpaw.FitOrderVolume = @n_FitOrderVolume
         AND EXISTS (SELECT 1 FROM @t_MultiOrder AS tmo WHERE tmo.PTLLoc = '' AND tmo.Style = @c_Style)
         GROUP BY tpaw.SortStation
         ORDER BY MAX(tpaw.RowID)

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         SET @n_RowID_SortLoc = 0         
         WHILE 1 = 1  -- PTL LOC
         BEGIN
            SET @n_CubicCapacity= 0.00
            SET @n_CubicCapacity_Max = 0.00
            SET @c_PTLLoc = ''
            
            SELECT TOP 1 @n_RowID_SortLoc = tpaw.RowID
                  , @n_CubicCapacity= tpaw.CubicCapacity
                  , @n_CubicCapacity_Max = tpaw.MaxCubicCapacity
                  , @c_PTLLoc = tpaw.Loc
            FROM @t_PTLAsgmtWIP AS tpaw
            WHERE tpaw.RowID > @n_RowID_SortLoc
            AND tpaw.SortStation = @c_SortStation 
            AND tpaw.FitOrderVolume = @n_FitOrderVolume
            AND EXISTS (SELECT 1 FROM @t_MultiOrder AS tmo WHERE tmo.PTLLoc = '' AND tmo.Style = @c_Style)
            ORDER BY tpaw.RowID
            
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            
            IF @b_Debug = 1
            BEGIN
               SELECT @c_PTLLoc '@c_PTLLoc' , @n_CubicCapacity '@n_CubicCapacity', @n_FitOrderVolume '@n_FitOrderVolume' 
                    , @n_CubicCapacity_Max'@n_CubicCapacity_Max'   
            END
             
            SET @c_Orderkey = ''      
            IF @n_FitOrderVolume = 1
            BEGIN
               IF @n_CubicCapacity = 0
               BEGIN
                  SELECT TOP 1 @c_Orderkey = tmo.Orderkey
                  FROM @t_MultiOrder AS tmo
                  WHERE tmo.Ord_Volume > @n_CubicCapacity_Max
                  AND   tmo.PTLLoc = ''
                  ORDER BY tmo.Orderkey
               END 
               ELSE IF @n_CubicCapacity > 0
               BEGIN
                  SELECT TOP 1 @c_Orderkey = tmo.Orderkey
                  FROM @t_MultiOrder AS tmo
                  WHERE tmo.Style = @c_Style
                  AND   tmo.PTLLoc = ''
                  AND   tmo.Ord_Volume <= @n_CubicCapacity
                  ORDER BY tmo.Ord_Volume 
                        ,  tmo.Orderkey
               END 
            END
            ELSE
            BEGIN
               SELECT TOP 1 @c_Orderkey = tmo.Orderkey
               FROM @t_MultiOrder AS tmo
               WHERE tmo.Style = @c_Style
               AND tmo.PTLLoc = ''
               AND tmo.Ord_Volume > 0
               ORDER BY tmo.Ord_Volume DESC
                     ,  tmo.Orderkey
            END 

            IF @c_Orderkey <> ''
            BEGIN
               UPDATE @t_SortLocCubic 
               SET Orderkey = @c_Orderkey
               WHERE Loc = @c_PTLLoc
               
               UPDATE tmo
                  SET PTLLoc = @c_PTLLoc
                     ,tmo.SortStation = @c_SortStation
               FROM @t_MultiOrder AS tmo
               WHERE tmo.Orderkey = @c_Orderkey 
            END

            IF @n_FitOrderVolume = 1 
            BEGIN
               SET @n_FitOrderVolume = 0
               IF EXISTS (
                           SELECT 1
                           FROM @t_MultiOrder AS tmo
                           WHERE tmo.PTLLoc = ''
                           AND tmo.Style = @c_Style
                           AND EXISTS (SELECT 1
                                       FROM @t_SortLocCubic AS tslc
                                       WHERE tslc.SortStation = @c_SortStation
                                       AND tslc.Orderkey = ''
                                       AND tmo.Ord_Volume < tslc.CubicCapacity
                                       )
                           )
               BEGIN
                  SET @n_FitOrderVolume = 1
               END
            
               IF @n_FitOrderVolume = 0
               BEGIN
                  INSERT INTO @t_PTLAsgmtWIP ( SortStation, CubicCapacity, MaxCubicCapacity, Loc, LogicalLocation, FitOrderVolume )
                  SELECT tslc.SortStation 
                        ,CubicCapacity = tslc.CubicCapacity
                        ,MaxCubicCapacity = tslc.MaxCubicCapacity 
                        ,tslc.Loc
                        ,tslc.LogicalLocation
                        ,FitOrderVolume = 0
                  FROM @t_SortLocCubic AS tslc 
                  WHERE tslc.Orderkey = ''
                  AND tslc.SortStation = @c_SortStation
                  ORDER BY tslc.SortStation
                        ,  tslc.CubicCapacity DESC
                        ,  tslc.LogicalLocation 
               END
            END
         END -- PTL LOC
      END-- PTL SortStation
   END 
   ------------------------------------------
   -- PTL Assignment - END
   ------------------------------------------  

   -----------------------------------------------
   -- Post PTL Assignment Check & Process - START
   -----------------------------------------------  
   IF EXISTS (SELECT 1 FROM @t_MultiOrder AS tmo WHERE tmo.PTLLoc = '')
   BEGIN
      --(Wan02) - START - Rollback TMReleaseFlag to 'N' and save PTLFAIL 
      --WHILE @@TRANCOUNT > 0 
      --BEGIN
      --   COMMIT TRAN
      --END
      IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END
      --(Wan02) - END
      
      UPDATE o WITH (ROWLOCK)
      SET   InvoiceNo = 'FAILPTL'         --Wan01
         ,  EditWho = SUSER_SNAME()
         ,  EditDate= GETDATE()
         ,  TrafficCop = NULL
      FROM ORDERS o 
      WHERE EXISTS ( SELECT 1 FROM @t_MultiOrder AS tmo 
                     WHERE tmo.PTLLoc = ''
                     AND tmo.Orderkey = o.OrderKey
                     )

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 62040
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update ORDERS Fail - Insuffient PTL Loc. (ispRLWAV43_PTL)'
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT < @n_StartTCnt 
      BEGIN
         BEGIN TRAN
      END
      
      SET @n_Continue = 3
      SET @n_Err = 62050
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insufficient PTL Loc for Multi Orders. (ispRLWAV43_PTL)'
      GOTO QUIT_SP
   END 
   
   SET @CUR_PTSK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   tmo.SortStation
   FROM @t_MultiOrder AS tmo
   GROUP BY tmo.SortStation
   
   OPEN @CUR_PTSK 
   
   FETCH NEXT FROM @CUR_PTSK INTO @c_SortStation
   
   WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
   BEGIN
   
      EXECUTE nspg_getkey    
        @KeyName     = 'ORDBATCHNO'    
      , @fieldlength = 9    
      , @keystring   = @c_TaskBatchNo     OUTPUT    
      , @b_Success   = @b_Success         OUTPUT    
      , @n_Err       = @n_Err             OUTPUT    
      , @c_ErrMsg    = @c_ErrMsg          OUTPUT    
      
      IF @b_Success= 0 
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END  
       
      SET @c_TaskBatchNo = 'B' + @c_TaskBatchNo  
             
      SET @c_PickZone = ''
      SELECT @c_PickZone = MIN(l.PickZone)
      FROM @t_MultiOrder AS tmo
      JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.Storerkey = tmo.Storerkey AND sul.Sku = tmo.Sku
                                           AND sul.LocationType = 'PICK'
      JOIN LOC AS l WITH (NOLOCK) ON l.Loc = sul.Loc
      WHERE tmo.SortStation = @c_SortStation
      GROUP BY l.Facility
      HAVING COUNT(DISTINCT l.PickZone) = 1
     
      INSERT INTO PACKTASK ( TaskBatchNo, Orderkey, DevicePosition, LogicalName, OrderMode )
      SELECT
            TaskBatchNo = @c_TaskBatchNo
         ,  tmo.Orderkey
         ,  tslc.DevicePosition
         ,  tslc.LogicalName     
         ,  OrderMode = CASE WHEN @c_PickZone = '' THEN 'M-4' ELSE 'M-1' END
      FROM @t_MultiOrder AS tmo
      JOIN @t_SortLocCubic AS tslc ON tslc.Loc = tmo.PTLLoc 
      WHERE tmo.SortStation = @c_SortStation
      GROUP BY tmo.Orderkey
            ,  tslc.DevicePosition
            ,  tslc.LogicalName   
   
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 62060
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update Pickdetail. (ispRLWAV43_PTL)'
         GOTO QUIT_SP
      END
         
      --(Wan03) - START
      --;WITH o ( Pickdetailkey ) AS
      --( 
      SET @CUR_UPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT pd.PickDetailKey
         FROM PACKTASK as pt WITH (NOLOCK)
         JOIN PICKDETAIL as pd WITH (NOLOCK) ON pt.Orderkey = pd.Orderkey
         WHERE pt.TaskBatchNo = @c_TaskBatchNo
         ORDER BY pd.PickDetailKey
      --)
      OPEN @CUR_UPD
      FETCH NEXT FROM @CUR_UPD INTO @c_PickDetailKey
      
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
      BEGIN
         UPDATE p WITH (ROWLOCK)
            SET PickSlipNo = @c_TaskBatchNo
               , Notes = @c_Wavekey + '-' + @c_PickZone + '-' + RIGHT(@c_TaskBatchNo,3) + CASE WHEN @c_PickZone = '' THEN '-4' ELSE '-1' END
               , EditWho  = SUSER_SNAME()
               , EditDate = GETDATE()
               , Trafficcop = NULL
         FROM PICKDETAIL as p
         --JOIN o ON o.PickDetailKey = p.PickDetailKey
         WHERE p.PickdetailKey = @c_Pickdetailkey

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 62070
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update Pickdetail. (ispRLWAV43_PTL)'
            GOTO QUIT_SP
         END
         FETCH NEXT FROM @CUR_UPD INTO @c_PickDetailKey
      END
      CLOSE @CUR_UPD
      DEALLOCATE @CUR_UPD
      --(Wan03) - END
      
      FETCH NEXT FROM @CUR_PTSK INTO @c_SortStation
   END
   CLOSE @CUR_PTSK
   DEALLOCATE @CUR_PTSK
   -----------------------------------------------
   -- Post PTL Assignment Check & Process - END
   -----------------------------------------------
  
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_PTL'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END   

GO