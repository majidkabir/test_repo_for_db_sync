SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Trigger:  ntrPODAdd                                                  */  
/* Creation Date: 2021-11-18                                            */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Trigger point Upon add POD                                  */  
/*        : WMS-18336 - MYS¿CSBUXM¿CDefault value in POD Entry column upon*/
/*        : update POD Status                                           */
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
/* Called By: When records inserted                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-11-18  Wan01    1.0   Created.                                  */
/* 2021-11-18  Wan01    1.0   DevOps Combine Script.                    */ 
/* 2023-02-08  YTKuek   1.1   Add Interface Trigger (YT01)              */
/************************************************************************/  
CREATE TRIGGER [dbo].[ntrPODAdd]  
ON  [dbo].[POD]  
FOR INSERT  
AS  
BEGIN    
IF @@ROWCOUNT = 0  
BEGIN  
   RETURN  
END  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE  
           @b_Success               int         -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err                   int         -- Error number returned by stored procedure or this trigger  
         , @n_err2                  int         -- For Additional Error Detection  
         , @c_errmsg                NVARCHAR(250)   -- Error message returned by stored procedure or this trigger  
         , @n_continue              int                   
         , @n_starttcnt             int         -- Holds the current transaction count  
         , @c_preprocess            NVARCHAR(250)   -- preprocess  
         , @c_pstprocess            NVARCHAR(250)   -- post process  
         , @n_cnt                   int     

   --(YT01)-S
   DECLARE @c_StorerKey             NVARCHAR(15)  
         , @c_MBOLKey               NVARCHAR(10)    
         , @c_MBOLLineNumber        NVARCHAR(5)     

   SET @c_StorerKey                 = ''
   SET @c_MBOLKey                   = ''
   SET @c_MBOLLineNumber            = ''
   --(YT01)-E

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
     /* #INCLUDE <TRPOHA1.SQL> */  
   
   --(YT01)-S
   --IF UPDATE(ArchiveCop)   
   --BEGIN  
   --   SELECT @n_continue = 4   
   --   RETURN   
   --END  
   --(YT01)-E

   IF @n_continue = 1 OR @n_continue = 2          
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED d  
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'PODTrigger_SP')  
      BEGIN            
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         SELECT * 
         INTO #INSERTED
         FROM INSERTED
            
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

         SELECT * 
         INTO #DELETED
         FROM DELETED

         EXECUTE dbo.isp_PODTrigger_Wrapper 
                   'INSERT' --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  

         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrPODAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   

   --(YT01)-S
   /********************************************************/    
   /* Interface Trigger Points Calling Process - (Start)   */    
   /********************************************************/    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN          
      DECLARE Cur_Order_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      -- Extract values for required variables    
      SELECT DISTINCT INS.Mbolkey  
                    , INS.Mbollinenumber    
                    , INS.StorerKey  
      FROM  INSERTED INS   
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey    
      WHERE ITC.SourceTable = 'POD'    
      AND   ITC.sValue      = '1'    
      UNION
      SELECT DISTINCT INS.Mbolkey  
                    , INS.Mbollinenumber    
                    , INS.StorerKey  
      FROM  INSERTED INS   
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = 'ALL'
      WHERE ITC.SourceTable = 'POD'    
      AND   ITC.sValue      = '1'       
  
      OPEN Cur_Order_TriggerPoints    
      FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_MBOLKey, @c_MBOLLineNumber, @c_Storerkey  
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         EXECUTE dbo.isp_ITF_ntrPOD     
                  @c_TriggerName    = 'ntrPODAdd'  
                , @c_SourceTable    = 'POD'    
                , @c_Storerkey      = @c_Storerkey  
                , @c_MBOLKey        = @c_MBOLKey    
                , @c_MBOLLineNumber = @c_MBOLLineNumber    
                , @b_ColumnsUpdated = 0      
                , @b_Success        = @b_Success   OUTPUT    
                , @n_err            = @n_err       OUTPUT    
                , @c_errmsg         = @c_errmsg    OUTPUT    
  
         FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_MBOLKey, @c_MBOLLineNumber, @c_Storerkey  
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE Cur_Order_TriggerPoints    
      DEALLOCATE Cur_Order_TriggerPoints    
   END -- IF @n_continue = 1 OR @n_continue = 2     
   /********************************************************/    
   /* Interface Trigger Points Calling Process - (End)     */    
   /********************************************************/    
   --(YT01)-E
   
     /* #INCLUDE <TRPOHA2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPODAdd'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END     

GO