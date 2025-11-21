SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_WaveReleaseLoadTask_Wrapper                    */  
/* Creation Date:                                                       */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 327746 - Release load plan task from wave load summary RCM  */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_WaveReleaseLoadTask_Wrapper]  
      @c_Wavekey NVARCHAR(10)
   ,  @c_LoadPlanList NVARCHAR(MAX)
   ,  @b_Success    INT OUTPUT    
   ,  @n_Err        INT OUTPUT
   ,	@c_Errmsg     NVARCHAR(255) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_TxtResult           NVARCHAR(MAX),
           @n_continue            INT,
           @c_LoadKey             NVARCHAR(10),
           @n_starttcnt           INT

   SELECT @n_continue = 1, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
   SET @n_starttcnt = @@TRANCOUNT  
   
   SELECT DISTINCT ColValue AS LoadKey
   INTO #TMP_LOADPLANLIST
   FROM dbo.fnc_DelimSplit('|',@c_LoadPlanList) 
   WHERE ISNULL(ColValue,'') <> ''
   
   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + LOADPLAN.Loadkey +', '
   FROM #TMP_LOADPLANLIST T
   JOIN LOADPLAN (NOLOCK) ON T.Loadkey = LOADPLAN.Loadkey
   WHERE LOADPLAN.ProcessFlag = 'L'
   ORDER BY T.Loadkey
   
   IF ISNULL(@c_TxtResult,'') <> ''
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81001 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': These Load are Currently Being Processed. ' + @c_TxtResult +
             ' (isp_WaveReleaseLoadTask_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END
   
   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + T.Loadkey +', '
   FROM #TMP_LOADPLANLIST T
   JOIN LOADPLANDETAIL (NOLOCK) ON T.Loadkey = LOADPLANDETAIL.Loadkey
   LEFT JOIN PICKDETAIL (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey)
   GROUP BY T.LOADKEY
   HAVING SUM(ISNULL(PICKDETAIL.Qty,0)) = 0
   ORDER BY T.Loadkey
   
   IF ISNULL(@c_TxtResult,'') <> ''
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81002 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': These Load Are Not Allocated Yet. ' + @c_TxtResult +
             ' (isp_WaveReleaseLoadTask_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END

   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + O.Storerkey +', '
   FROM #TMP_LOADPLANLIST T
   JOIN LOADPLANDETAIL (NOLOCK) ON T.Loadkey = LOADPLANDETAIL.Loadkey
   JOIN ORDERS O (NOLOCK) ON LOADPLANDETAIL.Orderkey = O.Orderkey
   WHERE NOT EXISTS (SELECT * FROM Storerconfig SC (NOLOCK) WHERE O.Storerkey = SC.Storerkey AND SC.Configkey = 'ReleasePickTaskCode' AND LEN(ISNULL(SC.Svalue,'')) > 1)   
   GROUP BY O.Storerkey
   ORDER BY O.Storerkey
   
   IF ISNULL(@c_TxtResult,'') <> ''
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81003 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': Please Setup Pick Task Strategy Code into Storer Configuration(ReleasePickTaskCode) For Storer. ' + @c_TxtResult +
             ' (isp_WaveReleaseLoadTask_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END
   
   --Clear invalid taskdetailkey at pickdetail
   UPDATE PICKDETAIL WITH (ROWLOCK)
   SET Taskdetailkey = '',
       TrafficCop = NULL
   FROM #TMP_LOADPLANLIST T
   JOIN ORDERS O (NOLOCK) ON T.Loadkey = O.Loadkey
   JOIN PICKDETAIL ON O.Orderkey = PICKDETAIL.Orderkey
   LEFT JOIN TASKDETAIL TD (NOLOCK) ON PICKDETAIL.Taskdetailkey = TD.Taskdetailkey
   WHERE ISNULL(TD.Taskdetailkey,'') = ''
   
   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + T.Loadkey +', '
   FROM #TMP_LOADPLANLIST T
   JOIN LOADPLANDETAIL (NOLOCK) ON T.Loadkey = LOADPLANDETAIL.Loadkey
   LEFT JOIN PICKDETAIL (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey)
   WHERE PICKDETAIL.Status = '0' 
   AND ISNULL(PICKDETAIL.Taskdetailkey,'') = ''
   GROUP BY T.LOADKEY
   HAVING SUM(ISNULL(PICKDETAIL.Qty,0)) = 0
   ORDER BY T.Loadkey
   
   IF ISNULL(@c_TxtResult,'') <> ''
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81004 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': These Load Have No Task To Release. ' + @c_TxtResult +
             ' (isp_WaveReleaseLoadTask_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END       

   SET @c_TxtResult = '' 
   SELECT @c_TxtResult = @c_TxtResult + T.Loadkey +', '
   FROM #TMP_LOADPLANLIST T
   JOIN LOADPLAN (NOLOCK) ON T.Loadkey = LOADPLAN.Loadkey
   JOIN ORDERS (NOLOCK) ON T.Loadkey = ORDERS.Loadkey
   JOIN V_Storerconfig2 SC2 ON ORDERS.Storerkey = SC2.Storerkey AND SC2.Configkey = 'LPRELTASKWITHBOOKING' AND SC2.Svalue = '1'
   WHERE ISNULL(LOADPLAN.BookingNo,0) = 0
   GROUP BY T.Loadkey
   ORDER BY T.Loadkey
   
   IF ISNULL(@c_TxtResult,'') <> ''
   BEGIN
      SELECT @c_TxtResult =  LEFT(@c_TxtResult,LEN(@c_TxtResult)-1)               
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81004 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
             ': These Load Have No Booking# And Not Allow To Release. ' + @c_TxtResult +
             ' (isp_WaveReleaseLoadTask_Wrapper) ( SQLSvr MESSAGE=' + @c_ErrMsg +  ' ) '      
      GOTO QUIT_SP
   END       
   
   DECLARE CUR_Load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT T.Loadkey
      FROM #TMP_LOADPLANLIST T
      ORDER BY T.Loadkey
 
   OPEN CUR_Load 
   FETCH NEXT FROM CUR_Load INTO @c_Loadkey
  
   WHILE (@@FETCH_STATUS<>-1)   
   BEGIN  
      EXEC nspLoadReleasePickTask_Wrapper @c_Loadkey = @c_Loadkey
      
      IF @@ERROR <> 0
      BEGIN      	
      	 SELECT @n_Continue = 3
      	 SELECT @n_Err = @@ERROR
      	 SELECT @c_ErrMsg = 'Error Release Pick Task For Load Plan ' + RTRIM(@c_Loadkey) + ' (isp_WaveReleaseLoadTask_Wrapper)'
         GOTO QUIT_SP
      END
    
      FETCH NEXT FROM CUR_Load INTO @c_LoadKey
   END
   
   CLOSE CUR_Load  
   DEALLOCATE CUR_Load  
      
   QUIT_SP:
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
   	  SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WaveReleaseLoadTask_Wrapper'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO