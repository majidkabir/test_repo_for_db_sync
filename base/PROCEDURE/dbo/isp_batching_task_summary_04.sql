SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_batching_task_summary_04                       */
/* Creation Date:  08-OCT-2019                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10760 [TW] Exceed View Report CR                        */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_batching_task_summary_04                             */
/*           copy from r_dw_batching_task_summary_02                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_batching_task_summary_04] (
            @c_Loadkey NVARCHAR(10)
           ,@c_OrderCount NVARCHAR(10) = '9999'
           ,@c_Pickzone NVARCHAR(1000) = ''
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N   --NJOW01
           ,@c_updatepick  NCHAR(1) = 'N' --(Wan02)
 )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_OrderCount   INT
           ,@b_Success      INT           
           ,@n_Err          INT           
           ,@c_ErrMsg       NVARCHAR(250)
           ,@c_ZoneList     NVARCHAR(1000) 
           ,@n_Continue     INT
           ,@n_StartTCnt    INT
           ,@c_CallSource   NVARCHAR(10)   
           ,@c_StorerKey    NVARCHAR(10)
           ,@c_autoscanin   NVARCHAR(5)
           ,@c_orderkey     NVARCHAR(20)
           ,@c_ORDStatus    NVARCHAR(20)        

    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)
    SELECT @c_ZoneList = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT 
            
    IF ISNULL(@c_PickZone,'') = ''
       SET @c_PickZone = ''
       
    IF @c_Mode NOT IN('1','4','5','9')
    BEGIN 
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63200  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_summary_04)' 
       GOTO Quit
    END
       
    IF @c_PickZone = 'ALL'
    BEGIN
      SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey 
      WHERE LPD.Loadkey = @c_Loadkey
      GROUP BY LOC.PickZone
      ORDER BY LOC.PickZone
      
      IF ISNULL(@c_ZoneList,'') <> ''
      BEGIN
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)
          SET @c_PickZone = @c_ZoneList
      END
    END       

    --NJOW01
    IF @c_ReGen = 'Y'
       SET @c_CallSource = 'RPTREGEN'
    ELSE
       SET @c_CallSource = 'RPT'   

    WHILE @@TRANCOUNT > 0
      COMMIT
      
    BEGIN TRAN  

    --(Wan02) - START
    EXEC ispOrderBatching
         @c_LoadKey     = @c_LoadKey
        ,@n_OrderCount  = @n_OrderCount  
        ,@c_PickZones   = @c_PickZone
        ,@c_Mode        = @c_Mode
        ,@b_Success     = @b_Success   OUTPUT  
        ,@n_Err         = @n_Err       OUTPUT  
        ,@c_ErrMsg      = @c_ErrMsg    OUTPUT
        ,@c_CallSource  = @c_CallSource
        ,@c_updatepick  = @c_updatepick
     --(Wan02) - END

    IF @b_Success = 0
    BEGIN       
       ROLLBACK
       SELECT @n_Continue = 3
       GOTO Quit
    END    
    
    WHILE @@TRANCOUNT > 0
      COMMIT

     SET @c_StorerKey = ''
     SET @c_autoscanin = 'N'

     SELECT TOP 1 @c_StorerKey = Storerkey
     FROM ORDERS (NOLOCK)
     WHERE loadkey = @c_LoadKey


     IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND    
                    SValue = '1' AND StorerKey = @c_StorerKey)
      BEGIN
       SET @c_autoscanin = 'Y'
     END
  

      EXEC isp_CreatePickSlip  
               @c_Loadkey = @c_LoadKey  
              ,@c_ConsolidateByLoad  = 'N'  --Y=Create load consolidate pickslip  
              ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno   
              ,@c_AutoScanIn         = @c_autoscanin  --Y=Auto scan in the pickslip N=Not auto scan in 
              ,@b_Success = @b_Success OUTPUT  
              ,@n_Err = @n_err OUTPUT   
              ,@c_ErrMsg = @c_errmsg OUTPUT          
            
        IF @b_Success = 0  
        BEGIN
         ROLLBACK
           SELECT @n_Continue = 3
           GOTO Quit     
          END

        DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
           SELECT DISTINCT ord.orderkey,ord.status
           FROM LOADPLANDETAIL LP (NOLOCK)
           JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
           JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
           JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
           JOIN ORDERS ORD (NOLOCK) ON ORD.Orderkey = PT.Orderkey
           where LP.loadkey= @c_LoadKey
           order by ord.orderkey 
  
         OPEN CUR_Orderkey   
     
         FETCH NEXT FROM CUR_Orderkey INTO @c_orderkey,@c_ordstatus    
     
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 

            IF @c_ordstatus < 3
            BEGIN
              UPDATE ORDERS
             SET STATUS ='3'
             WHERE Orderkey= @c_orderkey
             AND Status < 3
            END

         FETCH NEXT FROM CUR_Orderkey INTO @c_orderkey,@c_ordstatus
         END  
                          
    SELECT PT.TaskBatchNo, 
           PD.Notes, 
           LP.Loadkey, 
           COUNT(DISTINCT PD.Sku) AS NoOfSku,
           SUM(PD.Qty) AS Qty,
           L.PickZone,
           CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                CL.Long
           ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,
           COUNT(DISTINCT PD.Orderkey) AS NoOfOrder
          ,ISNULL(CDL.description,'') AS LOADDESC
    FROM LOADPLANDETAIL LP (NOLOCK)
    JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
    JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
    JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
    JOIN LOADPLAN LN WITH (NOLOCK) ON LN.loadkey=LP.loadkey
    LEFT JOIN CODELKUP CL (NOLOCK) ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
    LEFT JOIN CODELIST CDL (NOLOCK) ON CDL.listname = LN.userdefine04
    WHERE LP.Loadkey = @c_Loadkey
    AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
    AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
    GROUP BY PT.TaskBatchNo, 
             PD.Notes, 
             LP.Loadkey,
             L.PickZone,
             CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                CL.Long
             ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END 
          ,ISNULL(CDL.description,'')
    ORDER BY L.PickZone, PD.NOTES    
        
Quit:
   
   WHILE @@TRANCOUNT < @n_StartTCnt
       BEGIN TRAN

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_batching_task_summary_04'  
        --RAISERROR @n_Err @c_ErrMsg  
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END /* main procedure */

GO