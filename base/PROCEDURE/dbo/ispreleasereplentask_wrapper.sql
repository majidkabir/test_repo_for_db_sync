SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispReleaseReplenTask_Wrapper                       */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
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
/* 05/05/2017   NJOW01   1.0  WMS-1986 Add err output                   */
/************************************************************************/ 
CREATE PROC [dbo].[ispReleaseReplenTask_Wrapper]
@c_Facility NVARCHAR(10)='',
@c_zone02 NVARCHAR(10)='',
@c_zone03 NVARCHAR(10)='',
@c_zone04 NVARCHAR(10)='',
@c_zone05 NVARCHAR(10)='',
@c_zone06 NVARCHAR(10)='',
@c_zone07 NVARCHAR(10)='',
@c_zone08 NVARCHAR(10)='',
@c_zone09 NVARCHAR(10)='',
@c_zone10 NVARCHAR(10)='',
@c_zone11 NVARCHAR(10)='',
@c_zone12 NVARCHAR(10)='',
@c_Storerkey NVARCHAR(15)='',
@b_success INT = 1 OUTPUT,
@n_err    INT = 0 OUTPUT,
@c_errmsg NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @n_continue            INT,  
           @c_ReleasePickTaskCode NVARCHAR(30),  
           @c_SQL                 NVARCHAR(MAX),
           @c_SQLParms            NVARCHAR(MAX)  

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = '', @n_continue = 1, @c_ReleasePickTaskCode = ''
   
   SELECT @c_ReleasePickTaskCode = sVALUE   
   FROM   StorerConfig WITH (NOLOCK)   
   WHERE  StorerKey = CASE WHEN ISNULL(@c_StorerKey,'') <> '' THEN @c_StorerKey ELSE StorerKey END 
   AND    Facility  = CASE WHEN ISNULL(@c_Facility,'') <> '' THEN @c_Facility ELSE Facility END   
   AND    ConfigKey = 'ReleaseReplenTaskCode'

   IF ISNULL(RTRIM(@c_ReleasePickTaskCode),'') =''  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 81001 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Please Setup Replenishment Task Strategy Code into Storer Configuration(ReleaseReplenTaskCode). (ispReleaseReplenTask_Wrapper)'    
       GOTO QUIT_SP  
   END  
   SET @c_SQL = 'EXEC ' + @c_ReleasePickTaskCode + 
               ' @c_Facility  = @c_Facility '+
               ',@c_zone02    = @c_zone02   '+
               ',@c_zone03    = @c_zone03   '+
               ',@c_zone04    = @c_zone04   '+
               ',@c_zone05    = @c_zone05   '+
               ',@c_zone06    = @c_zone06   '+
               ',@c_zone07    = @c_zone07   '+
               ',@c_zone08    = @c_zone08   '+
               ',@c_zone09    = @c_zone09   '+
               ',@c_zone10    = @c_zone10   '+
               ',@c_zone11    = @c_zone11   '+
               ',@c_zone12    = @c_zone12   '+
               ',@c_Storerkey = @c_Storerkey'+
               ',@n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT'  

   SET @c_SQLParms = N'@c_Facility  NVARCHAR(10)='''', ' +
         '@c_zone02    NVARCHAR(10)='''', ' +
         '@c_zone03    NVARCHAR(10)='''', ' +
         '@c_zone04    NVARCHAR(10)='''', ' +
         '@c_zone05    NVARCHAR(10)='''', ' +
         '@c_zone06    NVARCHAR(10)='''', ' +
         '@c_zone07    NVARCHAR(10)='''', ' +
         '@c_zone08    NVARCHAR(10)='''', ' +
         '@c_zone09    NVARCHAR(10)='''', ' +
         '@c_zone10    NVARCHAR(10)='''', ' +
         '@c_zone11    NVARCHAR(10)='''', ' +
         '@c_zone12    NVARCHAR(10)='''', ' +
         '@c_Storerkey NVARCHAR(15)='''', ' +
         '@n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT'      
         
   EXEC sp_executesql @c_SQL, @c_SQLParms,   
        @c_Facility,@c_zone02,@c_zone03,@c_zone04   
       ,@c_zone05,@c_zone06,@c_zone07,@c_zone08   
       ,@c_zone09,@c_zone10,@c_zone11,@c_zone12   
       ,@c_Storerkey, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
     
   SELECT @n_Err = @@ERROR    
   IF @n_Err <> 0  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 81002 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Execute Release Pick Task Failed (ispReleaseReplenTask_Wrapper)' + ' ( '   
              + ' SQLSvr MESSAGE=' + @c_ErrMsg   
              + ' ) '         
       GOTO QUIT_SP  
   END  
     
   QUIT_SP:  
   IF @n_continue = 3  
   BEGIN  
   	   SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispReleaseReplenTask_Wrapper'    
       --RAISERROR @n_Err @c_ErrMsg  
       RAISERROR (@c_ErrMsg, -- Message text.
               16, -- Severity.
               1 -- State.
               );
   END                           
END -- procedure

GO