SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPickHeaderAdd                                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: James                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Add Pick Header Record                               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-Oct-2007  James     1.0   SOS80716 - When discrete pickslip is    */
/*                              printed and configkey 'TMSOutOrdHDR' is */
/*                              ON then Gen TMSLog for TMSHK.           */
/* 26-Mar-2009  YokeBeen  1.1   Added Trigger Point for CMS Project.    */
/*                              (SOS#170507) - (YokeBeen01)             */
/* 15-Sep-2015  NJOW01    1.2   352837 - update pickslip# to pickdetail */
/* 11-Oct-2016  TLTING01  1.3   Perfromance Tune                        */
/* 26-Jan-2108  MCTang    1.3   Enhance Generaic Trigger Interface(MC01)*/
/* 24-Feb-2023  GHUI      1.4   JSM-131455 -Add filter to fix           */          
/*                              performance issue                       */  
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPickHeaderAdd]
ON  [dbo].[PICKHEADER]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                  int       -- Error number returned by stored procedure or this trigger
         , @n_err2                 int       -- For Additional Error Detection
         , @c_errmsg               NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue             int                 
         , @n_starttcnt            int       -- Holds the current transaction count
         , @n_cnt                  int                  
         , @c_authority_tms        NVARCHAR(1) 
         , @c_Tablename            NVARCHAR(30) 
         , @c_StorerKey            NVARCHAR(15)
         , @c_orderkey             NVARCHAR(10)
         , @c_UserDefine08         NVARCHAR(10)
         , @c_authority            NVARCHAR(1) 
         , @n_TMSFleetWise         int 
         , @c_auth_LPALLOCCMS      NVARCHAR(1)   -- (YokeBeen01) 
         , @c_LoadKey              NVARCHAR(10)  -- (YokeBeen01) 
         , @c_UpdPickslipToPickDet NVARCHAR(10)  --NJOW01
         , @c_Facility             NVARCHAR(5)   --NJOW01
         , @c_Pickheaderkey        NVARCHAR(10)  --NJOW01
         , @c_Proceed              CHAR(1)       --(MC01)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --(MC01)      
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --(MC01)

   SET @c_Proceed = ''                             --(MC01)

   /* #INCLUDE <TRPHU1.SQL> */     
   IF @n_continue=1 or @n_continue=2
   BEGIN
	   --Added by James on 18/10/2007 SOS#80716 Start
      --check wether configkey has been setup for 'TMS_Fleetwise'
      EXEC nspGetRight 
            NULL,   -- Facility
            NULL,   -- Storer
            NULL,   -- No Sku in this Case
            'TMS_Fleetwise',	-- ConfigKey
            @b_success    		 output, 
            @c_authority   	 output, 
            @n_err        		 output, 
            @c_errmsg     		 output

      IF @c_authority = '1'
         SET @n_TMSFleetWise = 1 -- has been setup
      ELSE
         SET @n_TMSFleetWise = 0

      -- (YokeBeen01) - Start  
      -- Cursor Loop declaration
	  -- TLTING01
	  IF   EXISTS ( SELECT 1 FROM INSERTED 
					 JOIN ORDERS WITH (NOLOCK) ON (INSERTED.ExternOrderKey = ORDERS.LoadKey)
					WHERE ISNULL(RTRIM(INSERTED.Orderkey),'') = '' )
	  BEGIN
		  DECLARE Cur_PickHeaderAdd CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 			
		   SELECT Orders.Storerkey 
				, Orders.Orderkey  
				, Orders.UserDefine08 
				, INSERTED.ExternOrderKey 
				, Orders.Facility
				, INSERTED.Pickheaderkey
			 FROM INSERTED 
			 JOIN ORDERS WITH (NOLOCK) ON (INSERTED.ExternOrderKey = ORDERS.LoadKey)
			WHERE ISNULL(RTRIM(INSERTED.Orderkey),'') = '' and ISNULL(RTRIM(INSERTED.ExternOrderKey),'')<> ''  --JSM-131455  

	  END 
	  ELSE
	  BEGIN
		  DECLARE Cur_PickHeaderAdd CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 			
		   SELECT Orders.Storerkey 
				, INSERTED.Orderkey  
				, Orders.UserDefine08 
				, INSERTED.ExternOrderKey 
				, Orders.Facility --NJOW01
				, INSERTED.Pickheaderkey --NJOW01
			 FROM INSERTED 
			 JOIN ORDERS WITH (NOLOCK) ON (INSERTED.OrderKey = ORDERS.OrderKey)
			WHERE ISNULL(RTRIM(INSERTED.Orderkey),'') <> ''

	  END

      OPEN Cur_PickHeaderAdd
      FETCH NEXT FROM Cur_PickHeaderAdd INTO @c_StorerKey, @c_orderkey, @c_UserDefine08, @c_LoadKey, 
                                             @c_Facility, @c_Pickheaderkey --NJOW01

      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         IF @n_TMSFleetWise = 1
         BEGIN 
            SET @c_authority_tms = '0'

            SELECT @c_authority_tms = ISNULL(sValue, '0')
              FROM StorerConfig WITH (NOLOCK)
             WHERE StorerConfig.StorerKey = @c_StorerKey 
               AND ConfigKey = 'TMSOutOrdHDR'
			
            IF @c_authority_tms = '1' AND @c_UserDefine08 = 'Y'	--make sure is discrete order
            BEGIN
               IF ISNULL(RTRIM(@c_OrderKey),'') <> '' 
               BEGIN 
                  SET @c_Tablename = 'TMSOutOrdHDR'

                  EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, 'A', @c_StorerKey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=68000   
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                      + ': Insert into TMSLog Failed (ntrPickHeaderAdd) ( SQLSvr MESSAGE=' 
                                      + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END
               END -- IF ISNULL(RTRIM(@c_OrderKey),'') <> '' 
            END -- IF @c_authority_tms = '1' AND @c_UserDefine08 = 'Y' 
         END	--end for @nTMS_Fleetwise = 1
         -- Added by James on 18/10/2007 SOS#80716 End	 

         -- (YokeBeen01) - CMS Interface  
         IF @n_continue=1 or @n_continue=2
         BEGIN
            SELECT @c_auth_LPALLOCCMS = 0
            SELECT @b_success = 0

            EXEC nspGetRight 
                  NULL,           -- Facility
                  @c_StorerKey,   -- Storer
                  NULL,           -- No Sku in this Case
                  'LPALLOCCMS',   -- ConfigKey
                  @b_success           OUTPUT, 
                  @c_auth_LPALLOCCMS   OUTPUT, 
                  @n_err               OUTPUT, 
                  @c_errmsg            OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrPickHeaderAdd' + ISNULL(RTRIM(@c_errmsg),'')
            END
         END -- IF @n_continue=1 or @n_continue=2

         IF @b_success = 1 AND @c_auth_LPALLOCCMS = '1'
         BEGIN   
            IF ISNULL(RTRIM(@c_LoadKey),'') <> '' 
            BEGIN 
               EXEC ispGenCMSLOG 'LPALLOCCMS', @c_LoadKey, 'L', @c_StorerKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT 

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3 
                  SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=68001   
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                   + ': Insert into CMSLOG Failed (ntrPickHeaderAdd) ( SQLSvr MESSAGE=' 
                                   + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END     
            END -- IF ISNULL(RTRIM(@c_LoadKey),'') <> '' 
         END -- if @b_success = 1 AND @c_auth_LPALLOCCMS = '1' 
         -- (YokeBeen01) - End 
         
         --NJOW01
         IF (@n_continue=1 or @n_continue=2) AND ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            SELECT @c_UpdPickslipToPickDet = ''
            SELECT @b_success = 0

            EXEC nspGetRight 
                  @c_Facility,           -- Facility
                  @c_StorerKey,   -- Storer
                  NULL,           -- No Sku in this Case
                  'UpdPickslipToPickDet',   -- ConfigKey
                  @b_success              OUTPUT, 
                  @c_UpdPickslipToPickDet OUTPUT, 
                  @n_err               OUTPUT, 
                  @c_errmsg            OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ntrPickHeaderAdd' + ISNULL(RTRIM(@c_errmsg),'')
            END
            ELSE IF @c_UpdPickslipToPickDet = '1'
            BEGIN
            	 UPDATE PICKDETAIL WITH (ROWLOCK)
            	 SET Pickslipno = @c_Pickheaderkey,
            	     EditDate = GETDATE(),
            	     TrafficCop = NULL            	
            	 WHERE Orderkey = @c_Orderkey            	            	
            END
         END -- IF @n_continue=1 or @n_continue=2
                  
         FETCH NEXT FROM Cur_PickHeaderAdd INTO @c_StorerKey, @c_orderkey, @c_UserDefine08, @c_LoadKey, 
                                                @c_Facility, @c_Pickheaderkey  --NJOW01
      END -- End for WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_PickHeaderAdd
      DEALLOCATE Cur_PickHeaderAdd
   END -- @n_continue=1 or @n_continue=2

   /********************************************************/  
   /* Interface Trigger Points Calling Process - (Start)   */  
   /********************************************************/  
   --MC01 - S
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN 

      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                           
      SELECT DISTINCT IND.PickHeaderKey, OH.StorerKey                                                                    
      FROM   INSERTED IND  
      JOIN   Orders OH WITH (NOLOCK) ON IND.OrderKey = OH.OrderKey 
      WHERE  IND.OrderKey <> '' 
      UNION
      SELECT DISTINCT IND.PickHeaderKey, OH.StorerKey
      FROM   INSERTED IND        
      JOIN   LoadPlanDetail LD WITH (NOLOCK)    ON IND.LoadKey = LD.LoadKey  
      JOIN   Orders OH WITH (NOLOCK)            ON LD.OrderKey = OH.OrderKey  
      WHERE  IND.LoadKey <> ''       
                                                                               
      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_PickHeaderKey, @c_StorerKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_Proceed = 'N'

         IF EXISTS ( SELECT 1 
   	               FROM  ITFTriggerConfig ITC WITH (NOLOCK)       
   	               WHERE ITC.StorerKey   = @c_Storerkey
   	               AND   ITC.SourceTable = 'PickHeader'  
                     AND   ITC.sValue      = '1' )
         BEGIN
            SET @c_Proceed = 'Y'           
         END

         -- For OTMLOG StorerKey = 'ALL'
   	   IF EXISTS ( SELECT 1 
   	               FROM  StorerConfig STC WITH (NOLOCK)        
   	               WHERE STC.StorerKey = @c_Storerkey 
   	               AND   STC.SValue    = '1' 
   	               AND   EXISTS(SELECT 1 
                                  FROM  ITFTriggerConfig ITC WITH (NOLOCK)
   	                            WHERE ITC.StorerKey   = 'ALL' 
   	                            AND   ITC.SourceTable = 'PickHeader'  
                                  AND   ITC.sValue      = '1' 
                                  AND   ITC.ConfigKey   = STC.ConfigKey ) )
         BEGIN                  
            SET @c_Proceed = 'Y'                          	
         END  

         IF @c_Proceed = 'Y'
         BEGIN
            EXECUTE dbo.isp_ITF_ntrPickHeader   
                     @c_TriggerName    = 'ntrPickHeaderAdd'
                   , @c_SourceTable    = 'PickHeader'  
                   , @c_StorerKey      = @c_StorerKey 
                   , @c_PickHeaderKey  = @c_PickHeaderKey  
                   , @b_ColumnsUpdated = @b_ColumnsUpdated       
                   , @b_Success        = @b_Success OUTPUT  
                   , @n_err            = @n_err    OUTPUT  
                   , @c_errmsg         = @c_errmsg  OUTPUT  
         END

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_PickHeaderKey, @c_StorerKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints

   END
   --MC01 - E
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (End)     */  
   /********************************************************/  

   /* #INCLUDE <TRPHU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrPickHeaderAdd'
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