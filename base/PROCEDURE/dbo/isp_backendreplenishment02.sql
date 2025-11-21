SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_BackEndReplenishment02                         */
/* Creation Date: 10-Nov-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: WMS-3178 PH-Backend Create Replenishment Task By calling    */       
/*          replenishment report and release task stored proc           */
/*                                                                      */
/*                                                                      */
/* Called By: SQL Job                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/
CREATE PROC [dbo].[isp_BackEndReplenishment02]  
    @c_Storerkey                    NVARCHAR(15) = 'ALL'     
   ,@c_Facility                     NVARCHAR(5)  = ''
   ,@c_zone02                       NVARCHAR(10) = 'ALL'
   ,@c_zone03                       NVARCHAR(10) = ''
   ,@c_zone04                       NVARCHAR(10) = ''
   ,@c_zone05                       NVARCHAR(10) = ''
   ,@c_zone06                       NVARCHAR(10) = ''
   ,@c_zone07                       NVARCHAR(10) = ''
   ,@c_zone08                       NVARCHAR(10) = ''
   ,@c_zone09                       NVARCHAR(10) = ''
   ,@c_zone10                       NVARCHAR(10) = ''
   ,@c_zone11                       NVARCHAR(10) = ''
   ,@c_zone12                       NVARCHAR(10) = ''
   ,@c_ReplGrp                      NVARCHAR(30) = 'ALL'   
   ,@c_ReplenRpt_SPName             NVARCHAR(50) = ''
   ,@c_ReleaseReplen_SPName         NVARCHAR(50) = 'ispRLREP00'
AS   
BEGIN      
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT,
            @b_Success     INT, 
            @n_Err         INT,
            @c_ErrMsg      NVARCHAR(250),
            @c_SQL         NVARCHAR(4000)      
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''    
   
   
   IF ISNULL(@c_Storerkey,'') = ''
      SET @c_Storerkey = 'ALL'

   IF ISNULL(@c_Zone02,'') = ''
      SET @c_Zone02 = 'ALL'

   IF ISNULL(@c_ReplGrp,'') = ''
      SET @c_ReplGrp = 'ALL'

   IF ISNULL(@c_ReleaseReplen_SPName,'') = ''
      SET @c_ReleaseReplen_SPName = 'ispRLREP00'
      
   IF ISNULL(@c_Facility,'') = ''
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60300   
  	   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Blank Facility Parameter Is Not Allowed. (isp_BackEndReplenishment02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
  	   GOTO EXIT_SP
   END
      
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_ReplenRpt_SPName) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60310   
  	   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Stored Proc ''' + RTRIM(@c_ReplenRpt_SPName) + '''. (isp_BackEndReplenishment02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
  	   GOTO EXIT_SP
   END   

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_ReplenRpt_SPName) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60320   
  	   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Stored Proc ''' + RTRIM(@c_ReleaseReplen_SPName) + '''. (isp_BackEndReplenishment02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
  	   GOTO EXIT_SP
   END   
      
   IF @n_continue IN(1,2)
   BEGIN
      BEGIN TRAN

      SET @c_SQL = 'EXEC ' + RTRIM(@c_ReplenRpt_SPName) + ' @c_Zone01=@c_FacilityP, @c_Zone02=@c_Zone02P, @c_Zone03=@c_Zone03P, @c_Zone04=@c_Zone04P, @c_Zone05=@c_Zone05P, '  +
                   ' @c_Zone06=@c_Zone06P, @c_Zone07=@c_Zone07P, @c_Zone08=@c_Zone08P, @c_Zone09=@c_Zone09P, @c_Zone10=@c_Zone10P, @c_Zone11=@c_Zone11P, ' +
                   ' @c_Zone12=@c_Zone12P'  
                   
      IF EXISTS(SELECT 1 
                FROM [INFORMATION_SCHEMA].[PARAMETERS] 
                WHERE SPECIFIC_NAME = @c_ReplenRpt_SPName
                AND PARAMETER_NAME = '@c_Storerkey')
      BEGIN
      	 SET @c_SQL = @c_SQL +  ', @c_Storerkey=@c_StorerkeyP'
      END                             

      IF EXISTS(SELECT 1 
                FROM [INFORMATION_SCHEMA].[PARAMETERS]  
                WHERE SPECIFIC_NAME = @c_ReplenRpt_SPName
                AND PARAMETER_NAME = '@c_ReplGrp')
      BEGIN
      	 SET @c_SQL = @c_SQL +  ', @c_ReplGrp=@c_ReplGrpP'
      END                             

      IF EXISTS(SELECT 1 
                FROM [INFORMATION_SCHEMA].[PARAMETERS] 
                WHERE SPECIFIC_NAME = @c_ReplenRpt_SPName
                AND PARAMETER_NAME = '@c_BackEndJob')
      BEGIN
      	 SET @c_SQL = @c_SQL +  ', @c_BackEndJob=''Y'''
      END                             
      
      EXEC sp_executesql @c_SQL 
         , N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_Zone02P NVARCHAR(10), @c_Zone03P NVARCHAR(10), @c_Zone04P NVARCHAR(10), @c_Zone05P NVARCHAR(10),
             @c_Zone06P NVARCHAR(10), @c_Zone07P NVARCHAR(10), @c_Zone08P NVARCHAR(10), @c_Zone09P NVARCHAR(10), @c_Zone10P NVARCHAR(10), @c_Zone11P NVARCHAR(10),
              @c_Zone12P NVARCHAR(10), @c_ReplGrpP NVARCHAR(30)'          
         , @c_StorerKey
         , @c_Facility
         , @c_Zone02
         , @c_Zone03
         , @c_Zone04
         , @c_Zone05
         , @c_Zone06
         , @c_Zone07
         , @c_Zone08
         , @c_Zone09
         , @c_Zone10 
         , @c_Zone11
         , @c_Zone12
         , @c_ReplGrp
         
      IF @@ERROR  <> 0
      BEGIN
         SET @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60330   
			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute ''' + RTRIM(@c_ReplenRpt_SPName) + ''' Failed. (isp_BackEndReplenishment02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			END                                                                                                 
   END   
   
   IF @n_continue IN(1,2) AND EXISTS(SELECT 1
                                     From  REPLENISHMENT R (NOLOCK)   
                                     JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
                                     WHERE (LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
                                            OR @c_Zone02 = 'ALL'
                                           )
                                     AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '') 
                                     AND R.Confirmed = 'N'  
                                     AND R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                                  R.StorerKey ELSE @c_StorerKey END)
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_ReleaseReplen_SPName + ' @c_Facility=@c_FacilityP, @c_Zone02=@c_Zone02P, @c_Zone03=@c_Zone03P, @c_Zone04=@c_Zone04P, @c_Zone05=@c_Zone05P, '  +
                   ' @c_Zone06=@c_Zone06P, @c_Zone07=@c_Zone07P, @c_Zone08=@c_Zone08P, @c_Zone09=@c_Zone09P, @c_Zone10=@c_Zone10P, @c_Zone11=@c_Zone11P, ' +
                   ' @c_Zone12=@c_Zone12P, @c_Storerkey=@c_StorerkeyP, @n_err=@n_errP OUTPUT, @c_errmsg=@c_errmsgP OUTPUT '  

      EXEC sp_executesql @c_SQL 
         , N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_Zone02P NVARCHAR(10), @c_Zone03P NVARCHAR(10), @c_Zone04P NVARCHAR(10), @c_Zone05P NVARCHAR(10),
             @c_Zone06P NVARCHAR(10), @c_Zone07P NVARCHAR(10), @c_Zone08P NVARCHAR(10), @c_Zone09P NVARCHAR(10), @c_Zone10P NVARCHAR(10), @c_Zone11P NVARCHAR(10),
              @c_Zone12P NVARCHAR(10), @n_errP INT OUTPUT, @c_errmsgP NVARCHAR(250) OUTPUT'          
         , @c_StorerKey
         , @c_Facility
         , @c_Zone02
         , @c_Zone03
         , @c_Zone04
         , @c_Zone05
         , @c_Zone06
         , @c_Zone07
         , @c_Zone08
         , @c_Zone09
         , @c_Zone10
         , @c_Zone11
         , @c_Zone12
         , @n_err OUTPUT
         , @c_errmsg OUTPUT

        IF @n_err <> 0
        BEGIN
           SET @n_continue = 3
        END                                                                                                 
   END   
                 
EXIT_SP:  
      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_BackEndReplenishment02'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR          
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
END -- Procedure    

GO