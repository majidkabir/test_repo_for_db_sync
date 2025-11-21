SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV52_VLDN                                         */
/* Creation Date: 2022-05-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19633 - TH-Nike-Wave Release                            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-05-12  Wan      1.0   Created.                                  */
/* 2022-05-12  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV52_VLDN]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_debug       INT            = 0  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT            = @@TRANCOUNT
         , @n_Continue                 INT            = 1
                                       
   DECLARE @c_Facility                 NVARCHAR(5)    = ''
         , @c_Storerkey                NVARCHAR(15)   = ''
         , @c_DispatchPiecePickMethod  NVARCHAR(10)   =  ''  
         , @c_Status_ORD               NVARCHAR(10)   = ''
         , @c_OrderCheckFlag           NVARCHAR(20)   = ''
                                       
         , @n_Found                    INT            = 0
                                       

         , @n_NoOfHomeLoc              INT            = 0        
         , @n_DiffHomeLoc              INT            = 0     
         , @n_NoOfUCCToDP              INT            = 0
         , @n_EmptyDPLoc               INT            = 0                           

         , @c_Orderkey                 NVARCHAR(10)   = ''
         , @c_Sku                      NVARCHAR(20)   = '' 
         , @c_Loc                      NVARCHAR(10)   = '' 
         , @c_UCCNo                    NVARCHAR(20)   = ''
         
         , @c_Release_Opt5             NVARCHAR(4000) = ''  
         , @c_LooseBundleCheck         NVARCHAR(1)    = 'N'    
         
    
   DECLARE @t_HomeLoc_AL               TABLE 
         ( RowRef                      INT            IDENTITY(1,1)           PRIMARY KEY
         , Storerkey                   NVARCHAR(15)   NOT NULL DEFAULT('')   
         , Sku                         NVARCHAR(20)   NOT NULL DEFAULT('')  
         , NoOfHomeLoc                 INT            NOT NULL DEFAULT(0)
         , DiffHomeLoc                 INT            NOT NULL DEFAULT(0)
         , PiecePickLocWithID          NVARCHAR(10)   NOT NULL DEFAULT('') 
         , LocWithNoAreaKey            NVARCHAR(10)   NOT NULL DEFAULT('') 
         , PickZone                    NVARCHAR(10)                      
         )                             
                                       
   DECLARE @t_DropID_AL                TABLE 
         ( RowRef                      INT            IDENTITY(1,1)           PRIMARY KEY
         , Storerkey                   NVARCHAR(15)   NOT NULL DEFAULT('') 
         , Sku                         NVARCHAR(20)   NOT NULL DEFAULT('')            
         , DropID                      NVARCHAR(20)   NOT NULL DEFAULT('')  
         , Qty                         INT            NOT NULL DEFAULT(0)
         , UCCToDP                     NVARCHAR(20)   NOT NULL DEFAULT('') 
         )  
            
   SET @b_Success  = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  

   SELECT TOP 1 
      @c_DispatchPiecePickMethod = ISNULL(RTRIM(DispatchPiecePickMethod),'') 
   ,  @c_OrderCheckFlag = ISNULL(RTRIM(w.UserDefine08),'')                  
   ,  @c_Status_ORD  = o.[Status] 
   ,  @c_Storerkey   = o.Storerkey
   ,  @c_Facility    = o.Facility
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   ORDER BY o.Status DESC
   
   IF @c_DispatchPiecePickMethod NOT IN ('INLINE', 'DTC')  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81010  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid DispatchPiecePickMethod. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END 

   IF @c_Status_ORD = '0'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': All Orders are not allocated. (ispRLWAV52_VLDN)'
      GOTO QUIT_SP
   END
   
   IF @c_Status_ORD > '2'  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81030  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END

   SELECT @c_Release_Opt5 = fgr.Option5 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'ReleaseWave_SP' ) AS fgr  
   
   IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
               WHERE TD.Wavekey = @c_Wavekey  
               AND TD.Sourcetype LIKE 'ispRLWAV52%'  
               AND TD.Tasktype IN ('RPF', 'CPK', 'ASTCPK')  
               AND TD.Status <> 'X')   
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81040  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave has been released - RPF/CPK/ASTCPK. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END  
   
   SET @n_Found = 0
   SET @c_Sku = ''
   SELECT TOP 1 @c_Sku = RTRIM(p.Sku)  
               ,@n_Found =  CASE WHEN s.[Length] = 0.00 THEN 1
                                 WHEN s.Width = 0.00 THEN 1
                                 WHEN s.Height = 0.00 THEN 1
                                 WHEN CONVERT(DECIMAL(12,5),s.STDCUBE) = 0.00 THEN 1
                                 WHEN s.STDGROSSWGT = 0.00 THEN 1  
                                 WHEN CONVERT(DECIMAL(12,5),s.[Length] * s.Width * s.Height) - CONVERT(DECIMAL(12,5),s.STDCUBE) NOT BETWEEN -0.00001 AND 0.00001 THEN 1                         --(Wan03)                     --(Wan03) 
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
      SET @n_Err = 81050  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku Length, Width, Height, StdCube, StdGrossWgt not setup OR LxWxH <> StdCube. Sku:' + @c_Sku
                   +'. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END   
   
   SET @n_Found = 0
   SET @c_Sku = ''
   SELECT TOP 1 @c_Sku = RTRIM(p.Sku) 
               ,@n_Found =  CASE WHEN c.ListName IS NULL THEN 1
                                 WHEN ISNUMERIC(c.UDF04) = 0 THEN 1
                                 ELSE 0 
                                 END
   FROM dbo.WAVEDETAIL AS w (NOLOCK)  
   JOIN dbo.PICKDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey  
   JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
   LEFT JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SKUGROUP' 
                                             AND C.Code = s.BUSR7
                                             AND c.Storerkey = p.Storerkey
   WHERE w.Wavekey = @c_Wavekey 
   ORDER BY 2 DESC
   
   IF @n_Found = 1
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81060 
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SkuGroup not Found/ No Of Carton in DP setup incorrectly in Codelkup. Sku: ' + @c_Sku
                   + '. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END    

   SET @n_Found = 0
   SET @c_Sku = ''
   SELECT TOP 1 @c_Sku = RTRIM(p.Sku) 
               ,@n_Found =  CASE WHEN c.ListName IS NULL THEN 1
                                 WHEN c.UDF02 = '' THEN 1
                                 ELSE 0 
                                 END
   FROM dbo.WAVEDETAIL AS w (NOLOCK)  
   JOIN dbo.PICKDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey  
   JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
   LEFT JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'NIKELOC' 
                                             AND c.UDF01 = s.BUSR7
                                             AND c.Short = 'PPAST'
   WHERE w.Wavekey = @c_Wavekey 
   ORDER BY 2 DESC
   
   IF @n_Found = 1
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81070 
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PPA Pack Station Not Found in Codelkup. Sku: ' + @c_Sku
                   + '. (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END 
   INSERT INTO @t_HomeLoc_AL 
       (
           Storerkey
       ,   Sku
       ,   NoOfHomeLoc
       ,   DiffHomeLoc
       ,   PiecePickLocWithID 
       ,   LocWithNoAreaKey
       ,   PickZone                                     
       )
   SELECT p.Storerkey
         ,p.Sku
         ,NoOfHomeLoc = COUNT(DISTINCT CASE WHEN l.LocationType = 'DPBULK' AND SL.Sku IS NULL THEN '1' 
                                            ELSE SL.Loc END)
         ,DiffHomeLoc = MAX(CASE WHEN l.LocationType = 'DYNPPICK' AND p.Loc <> sl.Loc THEN 1 ELSE 0 END)
         ,PiecePickLocWithID = MAX(CASE WHEN p.UOM = '7' AND l.LocationType IN ('DPBULK', 'DYNPPICK') AND l.LoseID NOT IN (1) THEN p.Loc
                                        WHEN p.UOM = '7' AND l.LocationType IN ('DPBULK', 'DYNPPICK') AND p.id <> '' THEN p.Loc 
                                        WHEN p.UOM = '6' AND l3.LoseID NOT IN (1, NULL) THEN l3.Loc
                                        ELSE ''
                                   END) 
         ,LocWithNoAreaKey = MAX(CASE WHEN ad.Areakey IS NULL THEN p.Loc ELSE '' END)
         ,PickZone = MAX(l2.PickZone)
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)  
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON w.OrderKey = o.OrderKey
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.Orderkey = o.Orderkey 
   JOIN dbo.LOC AS l WITH (NOLOCK) ON l.loc = p.Loc                                           
   LEFT JOIN SKUxLOC AS sl WITH (NOLOCK) ON sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku AND sl.LocationType = 'PICK' 
   LEFT JOIN dbo.LOC AS l2 WITH (NOLOCK) ON l2.Loc = sl.Loc AND l2.LocationType = 'DYNPPICK' AND l2.Facility = @c_Facility
   LEFT JOIN dbo.LOC AS l3 WITH (NOLOCK) ON l2.PickZone = L3.PickZone AND l2.LocationType = 'DYNPICKP' AND l2.Facility = @c_Facility
   LEFT JOIN dbo.AreaDetail AS ad WITH (NOLOCK) ON l.PickZone = ad.PutawayZone
   WHERE w.Wavekey = @c_Wavekey
   AND p.[Status] < '5'
   GROUP BY p.Storerkey, p.Sku
   ORDER BY p.Storerkey, p.Sku
   
   IF @b_debug = 1
   BEGIN
      SELECT * FROM @t_HomeLoc_AL
   END

   SET @c_Sku = ''
   SET @n_NoOfHomeLoc = 0
   SET @n_DiffHomeLoc = 0
   SELECT TOP 1 
               @c_Sku = RTRIM(thla.Sku)
            ,  @n_NoOfHomeLoc = thla.NoOfHomeLoc
            ,  @n_DiffHomeLoc = thla.DiffHomeLoc
   FROM @t_HomeLoc_AL AS thla 
   ORDER BY thla.NoOfHomeLoc ASC, thla.DiffHomeLoc DESC
   
   IF @c_Sku <> '' AND @n_NoOfHomeLoc = 0  
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 81080    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Home location not found. Sku: ' + RTRIM(@c_Sku) + '. (ispRLWAV52_VLDN)'    
      GOTO QUIT_SP    
   END    
  
   IF @c_Sku <> '' AND @n_NoOfHomeLoc > 1
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 81090    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. More than 1 Home Loc Found. Sku:.' + RTRIM(@c_Sku) + '. (ispRLWAV52_VLDN)'   
      GOTO QUIT_SP               
   END

   IF @c_Sku <> '' AND @n_DiffHomeLoc > 0
   BEGIN 
      SET @n_Continue = 3    
      SET @n_Err = 81100    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Sku: ' + RTRIM(@c_Sku) + ' allocated to > 1 Home Loc found. (ispRLWAV52_VLDN)'      
      GOTO QUIT_SP               
   END
   
   SELECT TOP 1 
         @c_Loc = RTRIM(thla.PiecePickLocWithID)
   FROM @t_HomeLoc_AL AS thla 
   ORDER BY thla.PiecePickLocWithID DESC

   IF @c_Loc <> ''         
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 81110    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. PICKDETAIL''s ID found for None Bulk or DPBULK/DYNPPICK/DYNPICKP loc not lose id found. Loc: ' + @c_Loc + '. (ispRLWAV52_VLDN)' 
      GOTO QUIT_SP               
   END
   
   SET @c_Loc = ''
   SELECT TOP 1 
         @c_Loc = RTRIM(thla.LocWithNoAreaKey)
   FROM @t_HomeLoc_AL AS thla 
   ORDER BY thla.LocWithNoAreaKey DESC
   
   IF @c_Loc <> ''         
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 81120   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Missing Loc areakey. Loc: ' + @c_Loc + '. (ispRLWAV52_VLDN)' 
      GOTO QUIT_SP               
   END
   
   --Rules:
   --1. 1 UCCNo No Mix Sku
   --2. Mandatory Full UCC for UOM 2 & 6 
   INSERT INTO @t_DropID_AL (Storerkey, Sku, DropID, Qty, UCCToDP)
   SELECT p.Storerkey, Sku = MIN(p.Sku), DropID = p.DropID,  Qty=SUM(Qty)
         ,UCCToDP = MAX(CASE WHEN p.UOM = '6' THEN p.DropID ELSE '' END)
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
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
      SET @n_Err = 81130     
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. MutliSku found in UCCNo: ' + @c_UCCNo + '. (ispRLWAV52_VLDN)'   
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
      SET @n_Err = 81140     
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Not fully allocated UCCNo qty for UOM 2 & 6 found. UCCNo: ' + @c_UCCNo + '. (ispRLWAV52_VLDN)'   
      GOTO QUIT_SP               
   END  
   
   SET @n_Found = 0
   ;WITH DP AS
   (  SELECT tdia.Sku
            , NoOfUCCToDP = COUNT(DISTINCT UCCToDP)
            ,MaxUCCInDP = CASE WHEN ISNUMERIC(c.UDF04) = 0 THEN 0 ELSE c.UDF04 END
      FROM @t_DropID_AL AS tdia
      JOIN SKU as s WITH (NOLOCK) ON tdia.Storerkey = s.Storerkey AND tdia.Sku = s.Sku
      JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SKUGROUP' 
                                           AND C.Code     = s.SkuGroup
                                           AND c.Storerkey= s.Storerkey
                                      
      WHERE UCCToDP <> ''
      GROUP BY tdia.Sku
            ,  CASE WHEN ISNUMERIC(c.UDF04) = 0 THEN 0 ELSE c.UDF04 END
   )
   , adp AS
   (
      SELECT  thla.Sku, l.Facility, l.PickZone, l.loc
      FROM @t_HomeLoc_AL AS thla 
      JOIN LOC l WITH (NOLOCK) ON l.PickZone = thla.PickZone       
      LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON (LLI.Loc = l.Loc AND  LLI.Storerkey = @c_Storerkey  )                                         
      WHERE   l.Facility = @c_Facility
      AND     l.LocationType = 'DYNPICKP' 
      AND     thla.PickZone IS NOT NULL  
      GROUP BY thla.Sku, l.Facility, l.PickZone, l.loc   
      HAVING CASE WHEN ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0) = 0 THEN 0      
                              ELSE COUNT(1)      
                              END  = 0  
   )   
   SELECT  TOP 1
           @n_Found = CASE WHEN DP.NoOfUCCToDP > COUNT(adp.Loc) * dp.MaxUCCInDP THEN 1 ELSE 0 END
         , @n_NoOfUCCToDP = DP.NoOfUCCToDP 
         , @n_EmptyDPLoc  = COUNT(adp.Loc) * dp.MaxUCCInDP
   FROM dp 
   JOIN adp  ON adp.Sku = dp.Sku
   AND  dp.MaxUCCInDP > 0 
   GROUP BY dp.Sku, DP.NoOfUCCToDP, DP.MaxUCCInDP   
   ORDER BY 1 DESC   
      
   IF @n_Found = 1
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81150  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
                   +'No of UCC:' + CONVERT(NVARCHAR(5),@n_NoOfUCCToDP - @n_EmptyDPLoc) + ' still need(s) DP Loc (ispRLWAV52_VLDN)'  
      GOTO QUIT_SP  
   END
   
   SET @c_LooseBundleCheck = 'N'              
   SELECT @c_LooseBundleCheck = dbo.fnc_GetParamValueFromString('@c_LooseBundleCheck', @c_Release_Opt5, @c_LooseBundleCheck)   
   IF @c_LooseBundleCheck = 'Y'
   BEGIN
      SET @n_Found = 0
      SELECT TOP 1 
           @n_Found = 1
         , @c_Sku = RTRIM(p.Sku)
         , @c_Loc = MIN(RTRIM(l.loc))
         , @c_Orderkey = p.OrderKey
      FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
      JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
      JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = p.Loc
      JOIN dbo.SKU AS s WITH (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
      WHERE w.WaveKey = @c_wavekey
      AND   s.PackQtyIndicator > 1
      GROUP BY p.Orderkey, p.Storerkey, p.Sku, l.LoseUCC, s.PackQtyIndicator
      HAVING (SUM(p.Qty) % s.PackQtyIndicator) > 0
      ORDER BY p.Orderkey, p.Storerkey, p.Sku

      IF @n_Found = 1
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 81160   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loose Bundle Found. Sku: ' + @c_Sku + ', Loc: ' + @c_Loc + ', Orderkey: ' + @c_Orderkey
                      +'. (ispRLWAV52_VLDN)'                                                                                                  
         GOTO QUIT_SP  
      END
   END
    
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV52_VLDN'
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