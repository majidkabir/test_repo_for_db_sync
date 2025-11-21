SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGenCMSLog_POD                                   */  
/* Creation Date: 01-Jul-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Initial Design for NIKE China Dynamic Pick Project          */  
/*                                                                      */  
/*                                                                      */  
/* Called By: ue_print_pod IN MBOL Screen                               */  
/*                                                                      */  
/* Version: 1.2                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 01-JUL-2009  SHONG   1.0   SOS#140789 Insert CMSLOG When Print POD   */
/* 23-Jul-2009  SHONG   1.1   Rework-Change to StorerConfig PPnPodCMSÆ*  */
/* 28-SEP-2009  Leong   1.2   Bug Fix - Not allow re-trigger CMSLog for */
/*                                      same MBOLKey (Ref: SOS#140789)  */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispGenCMSLog_POD]
	@c_MBOLKey NVARCHAR(10), 
	@b_Success  int = 1 OUTPUT, 
	@n_err      int = 0 OUTPUT,
	@c_errmsg   NVARCHAR(215) = '' OUTPUT 
AS
BEGIN
   DECLARE @c_Auth_LPPKCFMCMS      NVARCHAR(1), 
           @c_LoadKey              NVARCHAR(10), 
           @c_StorerKey            NVARCHAR(10), 
           @n_continue             int, 
           @n_starttcnt            int

   SET @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN  

   DECLARE CUR_CMSLOG_LOADKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT LOADPLANDETAIL.LoadKey, ORDERS.StorerKey 
   FROM MBOLDETAIL WITH (NOLOCK) 
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = LOADPLANDETAIL.OrderKey)  
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)  
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey  
   AND   MBOLDETAIL.MBOLKey NOT IN (SELECT DISTINCT TRANSMITBATCH FROM CMSLOG WITH (NOLOCK) 
                                    WHERE TABLENAME = 'LPPKCFMCMS' 
                                    AND ISNULL(RTRIM(TRANSMITBATCH),'') <> '') -- Leong  
   OPEN  CUR_CMSLOG_LOADKEY        

   FETCH NEXT FROM CUR_CMSLOG_LOADKEY INTO @c_LoadKey, @c_StorerKey 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Auth_LPPKCFMCMS = 0
      SELECT @b_success = 0
      
      EXEC nspGetRight 
            NULL,           -- Facility
            @c_StorerKey,   -- Storer
            NULL,           -- No Sku in this Case
            'LPPnPodCMS',   -- ConfigKey
            @b_success           OUTPUT, 
            @c_Auth_LPPKCFMCMS   OUTPUT, 
            @n_err               OUTPUT, 
            @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ispGenCMSLog_POD' + ISNULL(RTRIM(@c_errmsg),'')
         GOTO RETURN_SP
      END

      IF @b_success = 1 AND @c_Auth_LPPKCFMCMS = '1'
      BEGIN   
         IF ISNULL(RTRIM(@c_LoadKey),'') <> '' 
         BEGIN
         -- EXEC ispGenCMSLOG 'LPPKCFMCMS', @c_LoadKey, 'L', @c_StorerKey, ''
            EXEC ispGenCMSLOG 'LPPKCFMCMS', @c_LoadKey, 'L', @c_StorerKey, @c_MBOLKey --Leong
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT 

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3 
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=68001   
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                + ': Insert into CMSLOG Failed (ispGenCMSLog_POD) ( SQLSvr MESSAGE=' 
                                + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               GOTO RETURN_SP
            END     
         END -- IF ISNULL(RTRIM(@c_LoadKey),'') <> '' 
      END -- if @b_success = 1 AND @c_Auth_LPPKCFMCMS = '1' 
       
      FETCH NEXT FROM CUR_CMSLOG_LOADKEY INTO @c_LoadKey, @c_StorerKey 
   END
   CLOSE CUR_CMSLOG_LOADKEY
   DEALLOCATE CUR_CMSLOG_LOADKEY
   -- SOS140790 -End 

RETURN_SP:
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispGenCMSLog_POD'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
END

GO