SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_VLDN                                         */
/* Creation Date: 2021-07-09                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-09  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/* 2021-10-22  Wan01    1.1   Add LxWxH = StdCube validation            */
/*                      1.1   CR 2.6                                    */
/* 2021-10-26  Wan02    1.2   Convert to REAL to compare                */
/* 2021-10-26           1.2   Home Loc/Pick Face Checking               */
/* 2021-11-02  Wan03    1.3   Check LxWxH against Stdcube by 0.00001    */
/*                            variance                                  */
/* 2021-11-07  Wan04    1.3   Add Validation: 1 UCC Multiple Sku in BULK*/
/*                            Location                                  */
/*                            FC UCC qty allocated for UOM '2' and '6'  */
/* 2021-11-11  Wan05    1.3   Add Validation: Lose ID For None Bulk Loc */
/* 2022-01-05  Wan06    1.4   WMS-17299 - CR 2.9. Revise Priority Values*/
/*                            for TM RPF Task. Additional validation to */
/*                            prompt HomeLoc Assignment                 */
/* 2022-02-09  Wan07    1.5   Fixed. For allocated stock from DPBULK,use*/ 
/*                            DBBULK's PickZone to find PackStation     */
/*                            regardless if there is Home Loc setup.    */
/* 2022-04-26  Wan08    1.6   WMS-19522 - RG - Adidas SEA - Release Wave*/
/*                            on DP Loc Sequence                        */
/* 2022-08-19  Wan09    1.7   Config for PH to skip Loadplaning required*/
/*                            check                                     */
/* 2023-01-10  Mingle   1.8   WMS-21440 - Add Validation: Not allow to  */
/*                            release wave when mbol not generated(ML01)*/
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV43_VLDN]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1
         
   DECLARE @c_Facility              NVARCHAR(5)  = ''
         , @c_Storerkey             NVARCHAR(15) = ''
         , @c_SortStationGroups     NVARCHAR(110)= ''
         , @c_Status_ORD            NVARCHAR(10)  = ''
         , @c_SortStationGroup_NF   NVARCHAR(100) = ''
         , @c_OrderCheckFlag        NVARCHAR(20)  = ''

         , @n_SortStationLoc        INT   = 0
         , @n_NoOfLargeLoc          INT   = 0
         , @n_CubicCapacity_Max     FLOAT = 0.00

         , @n_MultiOrder            INT   = 0
         , @n_NoOfLargeVolumeOrd    FLOAT = 0.00
         
         , @n_Found                 INT   = 0

         , @c_Sku                   NVARCHAR(20) = ''
         , @c_DiffHomeLoc_AL        NVARCHAR(10) = ''       --(Wan02)
         , @n_NoOfDPP_AL            INT          = 0        --(Wan02)
         , @n_NoOfHomeLoc           INT          = 0        --(Wan02)
         
         , @c_UCCNo                 NVARCHAR(20) = ''       --(Wan02)
         , @c_Loc                   NVARCHAR(10) = ''       --(Wan05)
         
         , @n_Loadplaning           INT          = 0        --(Wan08)
         
         , @c_Release_Opt5          NVARCHAR(4000) = ''     --(Wan08) CR 3.0
         , @c_SkuGroupSkipOptim     NVARCHAR(30)= ''        --(Wan08) CR 3.0
         
         , @c_SkipRequiredLoad      NVARCHAR(30)= ''        --(Wan09) Fix PH Production Issue
         , @c_CheckMBOLIsPopulated  NVARCHAR(30)= ''        --(ML01)
         , @c_mbolkey               NVARCHAR(10)= ''        --(ML01)
                     
         
   DECLARE @t_SortLocCubic          TABLE
         ( RowRef                   INT            IDENTITY(1,1)           PRIMARY KEY
         , Loc                      NVARCHAR(10)   NOT NULL DEFAULT('')    
         , SortStation              NVARCHAR(10)   NOT NULL DEFAULT('') 
         , SortStationGroup         NVARCHAR(10)   NOT NULL DEFAULT('') 
         , CubicCapacity            FLOAT          NOT NULL DEFAULT(0.00)
         , SortStationGroup_NF      NVARCHAR(10)   NOT NULL DEFAULT('') 
         )
   
   DECLARE @t_SkuPickZone           TABLE 
         ( RowRef                   INT            IDENTITY(1,1)           PRIMARY KEY
         , PickZone                 NVARCHAR(10)   NULL     DEFAULT('')    
         , DocType                  NVARCHAR(10)   NOT NULL DEFAULT('') 
         , PickLocType              NVARCHAR(10)   NOT NULL DEFAULT('')             --(Wan06)
         )
      
   --Wan01
   DECLARE @t_Orders                TABLE 
         ( Orderkey                 NVARCHAR(10)   NOT NULL DEFAULT('')    PRIMARY KEY
         , [Status]                 NVARCHAR(10)   NULL     DEFAULT('')  
         , ADCourier                INT            NOT NULL DEFAULT(0)
         )  
    
   --Wan02    
   DECLARE @t_HomeLoc_AL            TABLE 
         ( RowRef                   INT            IDENTITY(1,1)           PRIMARY KEY
         , Storerkey                NVARCHAR(15)   NOT NULL DEFAULT('')   
         , Sku                      NVARCHAR(20)   NOT NULL DEFAULT('')  
         , Loc                      NVARCHAR(10)   NOT NULL DEFAULT('')  
         , NoOFDPP                  INT            NOT NULL DEFAULT(0)
         , PickZone                 NVARCHAR(10)   NOT NULL DEFAULT('')                --(Wan05)
         )  
    
   --Wan04    
   DECLARE @t_DropID_AL             TABLE 
         ( RowRef                   INT            IDENTITY(1,1)           PRIMARY KEY
         , Storerkey                NVARCHAR(15)   NOT NULL DEFAULT('')   
         , DropID                   NVARCHAR(20)   NOT NULL DEFAULT('')  
         , Qty                      INT            NOT NULL DEFAULT(0)
         )  
            
   SET @b_Success  = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  
   
   SELECT TOP 1 
      @c_SortStationGroups = ISNULL(RTRIM(w.UserDefine01),'') + ',' + ISNULL(RTRIM(w.UserDefine02),'') + ',' --CR v2.5
                           + ISNULL(RTRIM(w.UserDefine03),'') + ',' + ISNULL(RTRIM(w.UserDefine04),'') + ','
                           + ISNULL(RTRIM(w.UserDefine05),'')
   ,  @c_OrderCheckFlag = ISNULL(RTRIM(w.UserDefine08),'')                  
   ,  @c_Status_ORD  = o.[Status] 
   ,  @c_Storerkey   = o.Storerkey
   ,  @c_Facility    = o.Facility
   ,  @n_Loadplaning = CASE WHEN lpd.LoadKey IS NULL THEN 0 ELSE 1 END
   ,  @c_mbolkey     = o.mbolkey --ML01
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   LEFT OUTER JOIN dbo.LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey               --(Wan08)
   WHERE w.WaveKey = @c_Wavekey
   ORDER BY CASE WHEN lpd.LoadKey IS NULL THEN 0 ELSE 1 END ASC                                       --(Wan08)
           ,o.Status ASC

   --(Wan08) - CR 3.0 - START                         --(Wan09) - Start. Move UP and SkipRequiredLoad
   EXEC nspGetRight          
         @c_Facility  = @c_Facility          
      ,  @c_StorerKey = @c_StorerKey         
      ,  @c_sku       = NULL          
      ,  @c_ConfigKey = 'ReleaseWave_SP'         
      ,  @b_Success   = @b_Success        OUTPUT          
      ,  @c_authority = ''           
      ,  @n_err       = @n_err            OUTPUT          
      ,  @c_errmsg    = @c_errmsg         OUTPUT   
      ,  @c_OPtion5   = @c_Release_Opt5   OUTPUT 
       
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   --(Wan08) - CR 3.0 - END
   
   SET @c_SkipRequiredLoad = 'N'       
   SELECT @c_SkipRequiredLoad = dbo.fnc_GetParamValueFromString('@c_SkipRequiredLoad', @c_Release_Opt5, @c_SkipRequiredLoad) 
 
   IF @n_Loadplaning = 0 AND @c_SkipRequiredLoad = 'N'                                                --(Wan08) - START
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61005
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Loadplan has not build yet. (ispRLWAV43_VLDN)'
      GOTO QUIT_SP   
   END                                                                                                --(Wan08) - END
   --(Wan09) - END                                                                                     
            
   IF @c_Status_ORD = '0'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Open Order found. (ispRLWAV43_VLDN)'
      GOTO QUIT_SP
   END
   
   --Wan01 - START
   INSERT INTO @t_ORDERS ( Orderkey, Status, ADCourier )	
   SELECT o.Orderkey, o.[Status], ADCourier = CASE WHEN c.LISTNAME IS NULL THEN 0 ELSE 1 END
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   LEFT OUTER JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'ADICOURIER'
                                                   AND c.Storerkey = o.StorerKey
                                                   AND c.Short = 'Y'
                                                   AND c.UDF01 = o.DocType
                                                   AND c.UDF02 = o.[Type]
                                                   AND c.UDF03 = o.Salesman
                                                   AND (c.UDF04 = '' OR c.UDF04 = o.DeliveryNote)
   WHERE w.WaveKey = @c_Wavekey
   GROUP BY o.Orderkey
         ,  o.[Status]
         ,  CASE WHEN c.LISTNAME IS NULL THEN 0 ELSE 1 END

            
   IF EXISTS ( SELECT 1 FROM @t_Orders AS tor WHERE tor.ADCourier = 1 AND tor.[Status] < '2'
               --SELECT 1 
               --FROM dbo.WAVE AS w WITH (NOLOCK)
               --JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
               --JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
               --JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'ADICOURIER'
               --                                     AND c.Storerkey = o.StorerKey
               --WHERE w.WaveKey = @c_Wavekey
               --AND o.[Status] < '2'
               --AND c.Short = 'Y'
               --AND c.UDF01 = o.DocType
               --AND c.UDF02 = o.[Type]
               --AND c.UDF03 = o.Salesman
               --AND c.UDF04 = o.DeliveryNote
            )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Partial Allocated AD Courier Order Found. (ispRLWAV43_VLDN)'
      GOTO QUIT_SP
   END
   
   IF @c_OrderCheckFlag <> 'BYPASS'
   BEGIN
      IF EXISTS ( SELECT 1 FROM @t_Orders AS tor WHERE tor.ADCourier = 0 AND tor.[Status] < '2')
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61021
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Partial Allocated Non AD Courier Order Found. (ispRLWAV43_VLDN)'
         GOTO QUIT_SP
      END
   END
   --Wan01 - END

   --START ML01
   SET @c_CheckMBOLIsPopulated = 'N'
   SELECT @c_CheckMBOLIsPopulated = dbo.fnc_GetParamValueFromString('@c_CheckMBOLIsPopulated', @c_Release_Opt5, @c_CheckMBOLIsPopulated) 
   
   IF @c_CheckMBOLIsPopulated = 'Y'
   BEGIN
      IF @c_mbolkey = NULL OR ISNULL(@c_mbolkey,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61022
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Not allow to release wave for picking due to order do not have mbolkey. (ispRLWAV43_VLDN)'
         GOTO QUIT_SP
      END
   END
   --END ML01
   
   IF EXISTS ( SELECT 1 FROM dbo.WAVE AS w WITH (NOLOCK)
               JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
               JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
               WHERE w.WaveKey = @c_Wavekey
               AND DocType = 'E'
               AND o.ECOM_SINGLE_Flag = 'M'
   )
   BEGIN
      IF @c_SortStationGroups = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61030
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Sort Station Group ID is required. (ispRLWAV43_VLDN)'
         GOTO QUIT_SP
      END

      SELECT @c_SortStationGroup_NF = RTRIM(ISNULL(CONVERT(VARCHAR(250),  
                                               ( 
                                                SELECT DISTINCT ss.[value] + ','
                                                FROM STRING_SPLIT(@c_SortStationGroups, ',') AS ss
                                                WHERE ss.[value] <> ''
                                                AND NOT EXISTS (
                                                                  SELECT l.Loc, l.PickZone, l.CubicCapacity, dp.DeviceID
                                                                  FROM dbo.DeviceProfile AS dp WITH (NOLOCK) 
                                                                  JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = dp.Loc
                                                                  WHERE dp.StorerKey = @c_Storerkey
                                                                  AND  l.LocationCategory = 'PTL'
                                                                  AND  l.LocationType= 'OTHER'        
                                                                  AND  l.LocationFlag = 'HOLD'  
                                                                  AND l.PickZone = LTRIM(RTRIM(ss.[value]))
                                                                  )
                                                FOR XML PATH(''), TYPE  
                                                )  
                                              )
                                         ,'')  
                                       )  
  
      IF @c_SortStationGroup_NF <> ''
      BEGIN
         SET @c_SortStationGroup_NF = SUBSTRING(@c_SortStationGroup_NF, 1, LEN(@c_SortStationGroup_NF) - 1 )

         SET @n_Continue = 3
         SET @n_Err = 61040
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Sort Station Group ID found: ' + @c_SortStationGroup_NF + '. (ispRLWAV43_VLDN)'
         GOTO QUIT_SP
      END
   END
   
   IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
               WHERE TD.Wavekey = @c_Wavekey  
               AND TD.Sourcetype LIKE 'ispRLWAV43%'  
               AND TD.Tasktype IN ('RPF', 'CPK', 'ASTCPK')  
               AND TD.Status <> 'X')   
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 61050  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave has been released - RPF/CPK/ASTCPK. (ispRLWAV43_VLDN)'  
      GOTO QUIT_SP  
   END  

   IF EXISTS ( SELECT 1   
               FROM WAVEDETAIL WD(NOLOCK)  
               JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
               WHERE O.Status > '2'  
               AND WD.Wavekey = @c_Wavekey  
             )  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 61060  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking. (ispRLWAV43_VLDN)'  
      GOTO QUIT_SP  
   END
   
   --(Wan08) CR 3.0 - START   
   SET @c_SkuGroupSkipOptim = '' 
   SELECT @c_SkuGroupSkipOptim = dbo.fnc_GetParamValueFromString('@c_SkuGroupSkipOptim', @c_Release_Opt5, @c_SkuGroupSkipOptim) 
   --(Wan08) CR 3.0 - END
   
   SET @n_Found = 0
   SET @c_Sku = ''
   SELECT TOP 1 @c_Sku = RTRIM(p.Sku)  
               ,@n_Found =  CASE WHEN s.STDCUBE = 0.00 THEN 1
                                 WHEN s.STDGROSSWGT = 0.00 THEN 1 
                                 WHEN CHARINDEX(s.SkuGroup, @c_SkuGroupSkipOptim, 1) > 0 THEN 0             --(WAN08) CR 3.0
                                 WHEN s.[Length] = 0.00 THEN 1                                              --(WAN08) CR 3.0 Move down
                                 WHEN s.Width = 0.00 THEN 1                                                 --(WAN08) CR 3.0 Move down
                                 WHEN s.Height = 0.00 THEN 1                                                --(WAN08) CR 3.0 Move down
                                 WHEN CONVERT(DECIMAL(12,5),s.[Length] * s.Width * s.Height) - CONVERT(DECIMAL(12,5),s.STDCUBE) NOT BETWEEN -0.00001 AND 0.00001 THEN 1                         --(Wan03)                     --(Wan03) 
                                 --WHEN ROUND(CONVERT(REAL,s.[Length] * s.Width * s.Height),5) <> ROUND(CONVERT(REAL,s.STDCUBE),5) THEN 1       --(Wan01) 
                                 --WHEN ROUND( s.[Length] * s.Width * s.Height,5) >= ROUND(s.STDCUBE,5) AND ROUND( s.[Length] * s.Width * s.Height,5) - ROUND(s.STDCUBE,5) > 0.00001 THEN 1     --(Wan02)                                       
                                 --WHEN ROUND( s.[Length] * s.Width * s.Height,5) <  ROUND(s.STDCUBE,5) AND ROUND(s.STDCUBE,5) - ROUND(s.[Length] * s.Width * s.Height,5) > 0.00001  THEN 1     --(Wan02)                                    
                                 ELSE 0 
                                 END 
   FROM dbo.WAVEDETAIL AS w (NOLOCK)  
   JOIN dbo.PICKDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey  
   JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
   WHERE w.Wavekey = @c_Wavekey   
   ORDER BY 2 DESC
 
   IF @n_Found = 1
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 61070  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku Length, Width, Height, StdCube, StdGrossWgt not setup OR LxWxH <> StdCube. Sku:' + @c_Sku
                   +'. (ispRLWAV43_VLDN)'  
      GOTO QUIT_SP  
   END   
   
   SET @n_Found = 0
   SET @c_Sku = ''
   SELECT TOP 1 @c_Sku = RTRIM(p.Sku) 
               ,@n_Found =  CASE WHEN C.ListName IS NULL THEN 1
                                 WHEN c.UDF01 = '' THEN 1
                                 WHEN c2.CartonizationKey IS NULL THEN 1
                                 ELSE 0 
                                 END
   FROM dbo.WAVEDETAIL AS w (NOLOCK)  
   JOIN dbo.PICKDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey  
   JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
   LEFT JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SKUGROUP' 
                                             AND C.Code = s.SkuGroup
                                             AND c.Storerkey = p.Storerkey
   LEFT JOIN dbo.CARTONIZATION AS c2 WITH (NOLOCK) ON c.UDF01 = c2.CartonizationGroup
   WHERE w.Wavekey = @c_Wavekey 
   ORDER BY 2 DESC
   
   IF @n_Found = 1
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 61080 
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SkuGroup/CartonGroup Not Found in Codelkup - SkuGroup/Cartonization. Sku: ' + @c_Sku
                   + '. (ispRLWAV43_VLDN)'  
      GOTO QUIT_SP  
   END    

   INSERT INTO @t_SkuPickZone (PickZone, DocType, PickLocType)                                  --(Wan06)
   SELECT PickZone = CASE WHEN l2.LocationType = 'DPBULK' THEN l2.PickZone ELSE l.PickZone END  --(Wan07)
         ,o.DocType
         ,CASE WHEN l2.LocationType = 'DPBULK' THEN 'DPBULK' ELSE 'NONDPBULK' END               --(Wan06)
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)  
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON w.OrderKey = o.OrderKey
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.Orderkey = o.Orderkey 
   JOIN dbo.LOC AS l2 WITH (NOLOCK) ON l2.loc = p.Loc                                           --(Wan06)
   LEFT JOIN SKUxLOC AS sl WITH (NOLOCK) ON sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku AND sl.LocationType = 'PICK' 
   LEFT JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = sl.Loc AND l.LocationType = 'DYNPPICK' AND l.Facility = @c_Facility
   WHERE w.Wavekey = @c_Wavekey
   GROUP BY CASE WHEN l2.LocationType = 'DPBULK' THEN l2.PickZone ELSE l.PickZone END           --(Wan07)
         ,  o.DocType
         ,  CASE WHEN l2.LocationType = 'DPBULK' THEN 'DPBULK' ELSE 'NONDPBULK' END             --(Wan06)
   
   IF EXISTS (SELECT 1 FROM @t_SkuPickZone AS tspz WHERE tspz.PickZone IS NULL
              AND tspz.PickLocType = 'NONDPBULK'                                                --(Wan06)
            )    
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 61090    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Sku''s home location not found. (ispRLWAV43_VLDN)'    
      GOTO QUIT_SP    
   END    
  
   IF EXISTS ( SELECT 1    
               FROM @t_SkuPickZone AS tspz   
               LEFT JOIN CODELKUP CL   WITH (NOLOCK) ON (CL.ListName = 'ADPICKZONE')    
                                                     AND(CL.Code  = tspz.PickZone)    
                                                     AND(CL.Code2 = tspz.DocType)     
                                                     AND(CL.Storerkey = @c_Storerkey)    
               LEFT JOIN LOC      PS   WITH (NOLOCK) ON (PS.Loc = CL.Short)     
               WHERE (CL.Code IS NULL OR PS.Loc IS NULL)    
             )                   
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 61100    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Pack Station not setup in codelkup OR Loc table. (ispRLWAV43_VLDN)'    
      GOTO QUIT_SP    
   END  
   
   --(Wan02) - START
   INSERT INTO @t_HomeLoc_AL 
       (
           Storerkey,
           Sku,
           Loc,
           NoOFDPP,
           PickZone                                               --(Wan05)
       )
   SELECT p.Storerkey
         ,p.Sku
         ,loc     = MIN(CASE WHEN l.LocationType = 'DYNPPICK' THEN p.Loc ELSE '' END)
         ,NoOFDPP = COUNT(DISTINCT CASE WHEN l.LocationType = 'DYNPPICK' THEN p.Loc ELSE NULL END)
         ,l.PickZone                                              --(Wan05)
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = p.Loc
   WHERE w.WaveKey = @c_Wavekey
   AND p.[Status] < '5'
   GROUP BY p.Storerkey, p.Sku, p.Loc, l.PickZone              --(Wan05)
   
   SET @c_Sku = ''
   SET @n_NoOfHomeLoc = 0
   SET @c_DiffHomeLoc_AL = ''
   SELECT TOP 1 
               @c_Sku = RTRIM(sul.Sku)
            ,  @n_NoOfHomeLoc   = COUNT(DISTINCT sul.Loc)
            ,  @n_NoOfDPP_AL    = thla.NoOFDPP
            ,  @c_DiffHomeLoc_AL = MAX(CASE WHEN thla.Loc <> '' AND thla.Loc <> sul.loc THEN thla.Loc ELSE '' END)
   FROM @t_HomeLoc_AL AS thla 
   JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.Storerkey = thla.StorerKey
                                          AND sul.Sku = thla.Sku
   WHERE sul.LocationType = 'PICK'
   GROUP BY sul.Storerkey, sul.Sku, thla.NoOFDPP
   ORDER BY 2 DESC, thla.NoOFDPP DESC

   IF @c_Sku <> '' AND @n_NoOfHomeLoc > 1
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 61110    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. More than 1 Home Loc Found. Sku:.' + RTRIM(@c_Sku) + '. (ispRLWAV43_VLDN)'   
      GOTO QUIT_SP               
   END

   IF @c_Sku <> '' AND @n_NoOfDPP_AL > 1
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 61120    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Sku:.' + RTRIM(@c_Sku) + ' allocated to > 1 DPP Loc found. (ispRLWAV43_VLDN)'      
      GOTO QUIT_SP               
   END
   
   IF @c_Sku <> '' AND @n_NoOfHomeLoc = 1 AND @c_DiffHomeLoc_AL <> ''
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 61130    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Different Allocated & Sku Home Loc found. Sku:' + RTRIM(@c_Sku) + '. (ispRLWAV43_VLDN)'   
      GOTO QUIT_SP               
   END   
   --(Wan02) - END
   
   --(Wan04) - START
   INSERT INTO @t_DropID_AL (Storerkey, DropID, Qty)
   SELECT p.Storerkey, DropID = p.DropID,  Qty=SUM(Qty)
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
   --JOIN dbo.UCC AS u WITH (NOLOCK) ON u.Storerkey = p.Storerkey AND u.UCCNo = p.DropID
   WHERE w.Wavekey = @c_Wavekey
   AND p.DropID <> ''
   AND p.[Status] < '5'
   AND p.UOM IN ('2','6')
   GROUP BY p.Storerkey, p.DropID 
 
   SET @c_UCCNo = ''
   SELECT TOP 1 @c_UCCNo = RTRIM(u.UCCNo)
   FROM @t_DropID_AL AS tdia
   JOIN dbo.UCC AS u WITH (NOLOCK) ON u.Storerkey = tdia.Storerkey AND u.UCCNo = tdia.DropID
   GROUP BY u.UCCNo 
   HAVING COUNT(DISTINCT u.Sku) > 1

   IF @c_UCCNo <> ''         
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 61140    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. MutliSku found in UCCNo: ' + @c_UCCNo + '. (ispRLWAV43_VLDN)'   
      GOTO QUIT_SP               
   END 
   
   SET @c_UCCNo = ''
   SELECT TOP 1 @c_UCCNo = RTRIM(u.UCCNo)
   FROM @t_DropID_AL AS tdia
   JOIN dbo.UCC AS u WITH (NOLOCK) ON u.Storerkey = tdia.Storerkey AND u.UCCNo = tdia.DropID
   WHERE tdia.Qty <> u.Qty

   IF @c_UCCNo <> ''         
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 61150    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Not fully allocated UCCNo qty for UOM 2 & 6 found. UCCNo: ' + @c_UCCNo + '. (ispRLWAV43_VLDN)'   
      GOTO QUIT_SP               
   END  
   --(Wan04) - END
   
   --(Wan05) - START
   SET @c_Loc = ''
   SELECT TOP 1 @c_Loc = CASE WHEN l.LoseId NOT IN ('1') THEN RTRIM(l.loc)
                             WHEN p.ID <> '' THEN RTRIM(l.loc)
                             ELSE ''
                             END
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = p.Loc
   WHERE w.WaveKey = @c_Wavekey
   AND p.[Status] < '5'
   AND p.UOM IN ('7')
   AND l.LocationType IN ('DPBULK', 'DYNPPICK')
   ORDER BY 1 DESC
   
   IF @c_Loc = ''
   BEGIN
      SELECT TOP 1 @c_Loc = RTRIM(l.Loc)  
      FROM @t_HomeLoc_AL AS thla 
      JOIN dbo.LOC AS l (NOLOCK) ON l.PickZone = thla.PickZone
      WHERE l.LoseId <> '1' 
      AND l.LocationType IN ( 'DYNPICKP')
      AND l.Facility = @c_Facility
      GROUP BY RTRIM(l.Loc) 
      ORDER BY RTRIM(l.Loc) 
   END
   
   IF @c_Loc <> ''         
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 61160    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. PICKDETAIL''s ID found for None Bulk or DPBULK/DYNPPICK/DYNPICKP loc not lose id found. Loc: ' + @c_Loc + '. (ispRLWAV43_VLDN)' 
      GOTO QUIT_SP               
   END
   
   --(Wan05) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_VLDN'
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
END   

GO