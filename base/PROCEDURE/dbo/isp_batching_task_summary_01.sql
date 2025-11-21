SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_Batching_Task_Summary_01                       */
/* Creation Date:  10-JUL-2017                                          */
/* Copyright: LF                                                        */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2304 - CN-Nike SDC WMS ECOM Generate PackTask CR        */
/*        :                                                             */
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
/* Called By: r_dw_batching_task_summary_01                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_Batching_Task_Summary_01] (
            @c_Loadkey     NVARCHAR(10) 
           ,@c_OrderCount  NVARCHAR(10) = '9999'
           ,@c_Pickzone    NVARCHAR(1000) = ''
           ,@c_Mode        NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single
           ,@c_ReGen       NVARCHAR(10) = 'N' -- Regnerate flag Y/N   
           ,@c_Wavekey     NVARCHAR(10) = ''          
           ,@c_UOM         NVARCHAR(500) = ''
         
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @n_OrderCount INT
         , @b_Success    INT           
         , @n_Err        INT           
         , @c_ErrMsg     NVARCHAR(250)
         , @c_ZoneList   NVARCHAR(1000) 
         , @n_Continue   INT
         , @n_StartTCnt  INT
         , @c_CallSource NVARCHAR(10)     


         , @c_Facility     NVARCHAR(5)     
         , @c_StorerKey    NVARCHAR(15) 
         , @c_BatchSource  NVARCHAR(2)       
         , @c_SQL          NVARCHAR(4000) 
         , @c_SQLArgument  NVARCHAR(4000)  

   SET @n_OrderCount = CONVERT(INT, @c_OrderCount)
   SET @c_ZoneList = ''
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT 

          
   IF ISNULL(@c_PickZone,'') = ''
   BEGIN
      SET @c_PickZone = ''
   END
       
   IF @c_Mode NOT IN('1','4','5','9')
   BEGIN 
      SET @n_Continue = 3  
      SET @n_Err = 63200  
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_Batching_Task_Summary_01)' 
      GOTO QUIT_SP
   END

   IF ISNULL(@c_LoadKey, '') <> '' AND ISNULL(@c_Wavekey, '') <> ''     
   BEGIN
      SELECT @n_Continue = 3  
      SELECT @n_Err = 63210  
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Not Allow to use both Loadkey And Wavekey to generate order batching'
                      +'. (isp_Batching_Task_Summary_01)'                  
      GOTO QUIT_SP
   END

   IF ISNULL(@c_LoadKey, '') = '' AND ISNULL(@c_Wavekey, '') = ''     
   BEGIN
      SELECT @n_Continue = 3  
      SELECT @n_Err = 63220  
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Both Loadkey And Wavekey are empty'
                      +'. (isp_Batching_Task_Summary_01)'                  
      GOTO QUIT_SP
   END

   SET @c_BatchSource = 'LP'
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''
   BEGIN       
      SELECT TOP 1 @c_Storerkey = Storerkey
                  ,@c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE UserDefine09 = @c_Wavekey
   
      SET @c_BatchSource = 'WP'
   END
 
   IF ISNULL(RTRIM(@c_Loadkey),'') <> ''                                
   BEGIN       
      SELECT TOP 1 @c_Storerkey = Storerkey
                  ,@c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END                                                                  

   --CREATE #TMP_PICKLOC and data insert to it in ispOrderBatching
   CREATE TABLE #TMP_PICKLOC
      (  PickDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')   PRIMARY KEY
      ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  TaskDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')
      )
   CREATE INDEX #IDX_PICKLOC_LOC ON #TMP_PICKLOC (Loc)    

   IF @c_ReGen = 'Y'
      SET @c_CallSource = 'RPTREGEN'
   ELSE
      SET @c_CallSource = 'RPT'   

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT
   END
      
   BEGIN TRAN  

   EXEC ispOrderBatching
       @c_LoadKey     = @c_Loadkey
      ,@n_OrderCount  = @n_OrderCount  
      ,@c_PickZones   = @c_PickZone  OUTPUT
      ,@c_Mode        = @c_Mode
      ,@b_Success     = @b_Success   OUTPUT  
      ,@n_Err         = @n_Err       OUTPUT  
      ,@c_ErrMsg      = @c_ErrMsg    OUTPUT
      ,@c_CallSource  = @c_CallSource
      ,@c_WaveKey     = @c_WaveKey
      ,@c_UOM         = @c_UOM

   IF @b_Success = 0
   BEGIN    	 
      ROLLBACK
      SET @n_Continue = 3
      GOTO QUIT_SP
   END    
 
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT
   END

   SET @c_SQL= N'SELECT'
             +'  PT.TaskBatchNo'
             +', PD.Notes' 
             + CASE WHEN @c_BatchSource = 'LP' THEN ', OH.Loadkey' ELSE ', OH.UserDefine09' END
             +', NoOfSku = COUNT(DISTINCT PD.Sku)'  
             +', Qty = ISNULL(SUM(PD.Qty),0)' 
             +', L.PickZone'
             +', ModeDesc = CASE WHEN ISNULL(CL.Long,'''') <> '''' THEN CL.Long'
             +'                  ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'''')),1) END' 
             +', COUNT(DISTINCT PD.Orderkey) AS NoOfOrder' 
             +' FROM ORDERS OH WITH (NOLOCK)'
             +' JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey'
             +' JOIN PACKTASK   PT WITH (NOLOCK) ON PD.Orderkey = PT.Orderkey'
             +' JOIN #TMP_PICKLOC PL WITH (NOLOCK) ON PD.PickDetailkey = PL.PickDetailkey'
             +' JOIN LOC L WITH (NOLOCK) ON L.Loc = PL.Loc' 
             +' LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'''')),1) = CL.Code AND CL.Listname = ''BATCHMODE''' 
             + CASE WHEN @c_BatchSource = 'LP' 
                    THEN ' WHERE OH.Loadkey = @c_Loadkey' 
                    ELSE ' WHERE OH.UserDefine09 = @c_Wavekey'
                    END
             +' AND EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit('','',@c_PickZone) WHERE ColValue = L.Pickzone)'
             +' AND RIGHT(RTRIM(ISNULL(PD.Notes,'''')),1) = @c_Mode'
             + CASE WHEN @c_UOM = '' THEN ''
                    ELSE ' AND EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit('','',@c_UOM ) WHERE ColValue = PD.UOM)'
                    END 

             +' GROUP BY PT.TaskBatchNo'
             +        ', PD.Notes' 
             +  CASE WHEN @c_BatchSource = 'LP' THEN ', OH.Loadkey' ELSE ', OH.UserDefine09' END
             +        ', L.PickZone'
             +        ', CASE WHEN ISNULL(CL.Long,'''') <> '''' THEN CL.Long'
             +        '       ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'''')),1) END' 
             +' ORDER BY L.PickZone, PD.NOTES' 

   SET @c_SQLArgument = N'@c_Loadkey   NVARCHAR(10)'
                      + ',@c_Wavekey   NVARCHAR(10)'
                      + ',@c_PickZone  NVARCHAR(1000)'
                      + ',@c_Mode      NVARCHAR(10)'
                      + ',@c_UOM       NVARCHAR(500)'
  
   EXEC sp_executesql @c_SQL
         ,  @c_SQLArgument
         ,  @c_Loadkey
         ,  @c_Wavekey 
         ,  @c_PickZone
         ,  @c_Mode
         ,  @c_UOM

QUIT_SP:
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_Batching_Task_Summary_01'  
        --RAISERROR @n_Err @c_ErrMsg  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END /* main procedure */

GO