SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ntrLoadPlanDelete                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Fire and perform requested process, when Loadplan Deletion */
/*           is took place.                                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-Mar-2009  YokeBeen  1.1   Added Trigger Point for CMS Project.    */
/*                              - SOS#170510 - (YokeBeen01)             */
/* 18-Mar-2010  TLTING    1.2   Delete LoadPlanLaneDetail (tlting01)    */
/*  9-Jun-2011  KHLim01   1.3   Insert Delete log                       */
/* 14-Jul-2011  KHLim02   1.4   GetRight for Delete log                 */
/* 11-Apr-2016  Leong     1.5   TS00009807 - Update LoadplanLaneDetail  */
/*                              EditDate.                               */
/* 18-Jul-2016  SHONG01   1.6   Update LoadKey to Pick & Pack Tables    */
/*                              SOS#373412                              */ 
/* 27-Jul-2017  TLTING    1.4   Missing NOLOCK                          */
/* 29-Sep-2018  TLTING    1.5   remove row lock                          */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLoadPlanDelete]
ON [dbo].[LoadPlan]
FOR DELETE
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

   DECLARE @b_Success     int         -- Populated by calls to stored procedures - was the proc successful?
         , @n_err         int         -- Error number returned by stored procedure or this trigger
         , @c_errmsg      NVARCHAR(250)   -- Error message returned by stored procedure or this trigger
         , @n_continue    int         -- continuation flag: 1=Continue, 2=failed but continue processsing,
                                         -- 3=failed do not continue processing, 4=successful but skip further processing
         , @n_starttcnt   int         -- Holds the current transaction count
         , @n_cnt         int         -- Holds the number of rows affected by the DELETE statement that fired this trigger.
         , @c_loadkey     NVARCHAR(10)
         , @c_PickSlipNo  NVARCHAR(10)
         , @c_facility    NVARCHAR(5)     -- Added for IDSV5 by June 26.Jun.02
         , @c_authority   NVARCHAR(1)     -- Added for IDSV5 by June 26.Jun.02
         
         , @cKeepPickHDWhenLpdDelete   NVARCHAR(1)  --SHONG01
         , @c_DelOrderKey              NVARCHAR(10) --SHONG01
         
    SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

      /* #INCLUDE <TRMBOHD1.SQL> */
   IF (SELECT count(*) FROM DELETED) = (SELECT count(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT * FROM DELETED WHERE Status = '9')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 72701
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                          + ': DELETE rejected. LoadPlan.Status = ''Shipped''. (ntrLoadPlanDelete)'
      END
   END

   -- SOS32395 : Move from 'BATCHPICK'
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Facility = Facility
      FROM   DELETED
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      Execute nspGetRight @c_Facility, -- facility, SOS32395
               null,    -- Storerkey
               null,          -- Sku
               'FinalizeLP',     -- Configkey
               @b_success     output,
               @c_authority   output,
               @n_err         output,
               @c_errmsg      output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrLoadplanDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE IF @c_authority = '1'
      BEGIN
         -- Once finalized, no more deletion allowed, requested by KO, 5th Jan 2002
         IF EXISTS (SELECT 1 FROM DELETED WHERE FinalizeFlag = 'Y' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=73000
            SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),ISNULL(@n_err,0))
                             + ': Loadplan has been finalized. DELETE rejected. (ntrLoadPlanDelete)'
         END
      END
   END   -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** End

   -- Modified for Batch Pick
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** Start
      SELECT @b_success = 0
      Execute nspGetRight @c_Facility, -- facility
               null,    -- Storerkey
               null,          -- Sku
               'BATCHPICK',         -- Configkey
               @b_success     output,
               @c_authority   output,
               @n_err         output,
               @c_errmsg      output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrLoadplanDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE IF @c_authority = '1'
      BEGIN  -- Added for IDSV5 by June 26.Jun.02, (extract from IDSHK) *** End
         -- only allow delete of loadplan if NONE of the batchpick tasks are completed
         IF EXISTS (SELECT 1 FROM Taskdetail WITH (NOLOCK)
                      JOIN DELETED ON ( Taskdetail.Sourcekey = DELETED.Loadkey )
                     WHERE Taskdetail.Sourcetype = 'BATCHPICK'
                     AND Taskdetail.Status = '9' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 72702
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                             + ': DELETE rejected. Some RF Tasks has been completed . (ntrLoadPlanDelete)'
         END
      END -- by June SOS29101

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         -- to delete the details, we need to bypass the trigger,
         -- as it disallow delete of detail when task has been released.
         -- delete of loadplan can only be from the header, which means deleting all the related tasks and pickslips.
         IF EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)
                      JOIN DELETED ON ( DELETED.Loadkey = LOADPLANDETAIL.Loadkey ))
         BEGIN
            UPDATE Loadplandetail  
               SET trafficcop = '9'
              FROM LOADPLANDETAIL
              JOIN DELETED ON ( DELETED.Loadkey = LOADPLANDETAIL.Loadkey )
         END

         -- sos 6710
         -- check if there any return loadplan details
         -- wally 18.july.2002
         IF EXISTS (SELECT 1 FROM LOADPLANRETDETAIL WITH (NOLOCK)
                      JOIN DELETED ON ( DELETED.Loadkey = LOADPLANRETDETAIL.Loadkey ))
         BEGIN
            UPDATE LOADPLANRETDETAIL  
               SET trafficcop = '9'
              FROM LOADPLANRETDETAIL
              JOIN DELETED ON (DELETED.Loadkey = LOADPLANRETDETAIL.Loadkey)
         END
         -- tlting01 start
         IF EXISTS (SELECT 1 FROM LoadPlanLaneDetail WITH (NOLOCK)
                      JOIN DELETED ON ( DELETED.Loadkey = LoadPlanLaneDetail.Loadkey ))
         BEGIN
            UPDATE LoadPlanLaneDetail  
               SET trafficcop = '9'
                 , EditDate = GETDATE() -- TS00009807
              FROM LoadPlanLaneDetail
              JOIN DELETED ON ( DELETED.Loadkey = LoadPlanLaneDetail.Loadkey )
         END -- tlting01 end

         -- delete tasks
         IF EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK)
                      JOIN DELETED ON (DELETED.Loadkey = TASKDETAIL.Sourcekey)
                     WHERE TASKDETAIL.Sourcetype = 'BATCHPICK' )
         BEGIN
            SELECT DISTINCT @c_loadkey = LOADKEY FROM DELETED
            DELETE TASKDETAIL
             WHERE SOURCEKEY = @c_loadkey
               AND SOURCETYPE = 'BATCHPICK'

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 72703
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                + ': DELETE rejected. Some RF Tasks has been completed . (ntrLoadPlanDelete)'
            END
         END   -- IF EXISTS
         -- delete Pick slip

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_PickSlipNo = ''
            SELECT @c_PickSlipNo = Pickheaderkey 
            FROM   PICKHEADER with (NOLOCK)
            WHERE  ExternOrderkey = @c_loadkey

            IF ISNULL(RTRIM(@c_PickSlipNo),'') <> ''
            BEGIN
               -- SHONG01
         	   SET @cKeepPickHDWhenLpdDelete = ''  

               SELECT TOP 1 
                     @cKeepPickHDWhenLpdDelete = ISNULL(sValue, '0')   
               FROM  STORERCONFIG WITH (NOLOCK)   
               JOIN  ORDERS AS o WITH (NOLOCK) ON o.StorerKey = STORERCONFIG.StorerKey 
               JOIN LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey  
               WHERE lpd.LoadKey = @c_loadkey    
               AND   ConfigKey = 'KeepPickHDWhenLpdDelete'   
               AND   sVAlue = '1' 
      
               IF @cKeepPickHDWhenLpdDelete <> '1'
               BEGIN
                  -- delete pick header info
                  DELETE PICKHEADER
                  WHERE ExternOrderkey = @c_loadkey

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72704
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                      + ': Unable to delete Pickslip. (ntrLoadPlanDelete)'
                                      + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     -- delete picking info
                     DELETE PICKINGINFO
                      WHERE PICKSLIPNO = @c_PickSlipNo

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72705
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                                         + ': Unable to delete Pickslip. (ntrLoadPlanDelete)'
                                         + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END -- @n_continue       	
               END
               ELSE 
               BEGIN
               	DECLARE DEL_PickSlipNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               	SELECT p.PickHeaderKey 
               	FROM PICKHEADER AS p WITH (NOLOCK)
               	WHERE p.ExternOrderKey = @c_loadkey 
               	
               	OPEN DEL_PickSlipNo 
               	FETCH NEXT FROM DEL_PickSlipNo INTO @c_PickSlipNo 
               	
               	WHILE @@FETCH_STATUS = 0 
               	BEGIN
            	      UPDATE PICKHEADER 
            	       SET ExternOrderKey = '', 
            	           TrafficCop = NULL, 
            	           EditDate = GETDATE(), 
            	           EditWho = SUSER_SNAME() 
            	      WHERE ExternOrderKey = @c_loadkey 
            	        AND OrderKey = @c_DelOrderKey  
            	        AND PickHeaderKey = @c_PickSlipNo  
            	   
            	      IF EXISTS(SELECT 1 FROM PackHeader AS ph WITH (NOLOCK)
            	                WHERE ph.PickSlipNo = @c_PickSlipNo 
            	                AND   ph.LoadKey = @c_loadkey )
            	      BEGIN
            	   	   UPDATE PackHeader  
            	   	      SET LoadKey = ''
            	   	   WHERE PickSlipNo = @c_PickSlipNo
            	   	            	   	
            	      END -- PackHeader 
            	      IF EXISTS(SELECT 1 FROM RefKeyLookup AS rkl WITH (NOLOCK)
            	                WHERE rkl.Pickslipno = @c_PickSlipNo 
            	                AND rkl.Loadkey = @c_loadkey)
            	      BEGIN
            	   	   UPDATE RefKeyLookup
            	   	      SET Loadkey = ''
            	   	   WHERE Pickslipno = @c_PickSlipNo  
            	         AND Loadkey = @c_loadkey
            	      END -- RefKeyLookup
               		FETCH NEXT FROM DEL_PickSlipNo INTO @c_PickSlipNo 
               	END      	      
               	CLOSE DEL_PickSlipNo
               	DEALLOCATE DEL_PickSlipNo
               END -- @cKeepPickHDWhenLpdDelete = 1               	
            END -- @c_PickSlipNo exists 
         END -- @n_continue
      END -- @n_continue
   -- END -- Authority = 1 : SOS29101
   END   -- End  Batch Picking

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE LoadPlanDetail
        FROM LoadPlanDETAIL
        JOIN DELETED ON (LoadPlanDETAIL.LoadKey = DELETED.LoadKey)
       WHERE LOADPLANDETAIL.Trafficcop = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72706
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                          + ': Delete Trigger On Table LoadPlanDETAIL Failed. (ntrLoadPlanDelete)'
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   -- SOS 6710
   -- delete any return loadplan details
   -- wally 18.july.2002
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE LoadPlanRetDetail
        FROM LoadPlanRetDETAIL
        JOIN DELETED ON (LoadPlanRetDETAIL.LoadKey = DELETED.LoadKey)
       WHERE LOADPLANRetDETAIL.Trafficcop = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72707
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                          + ': Delete Trigger On Table LoadPlanRetDETAIL Failed. (ntrLoadPlanDelete)'
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   -- tlting01 Start
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE LoadPlanLaneDetail
        FROM LoadPlanLaneDetail
        JOIN DELETED ON (LoadPlanLaneDetail.LoadKey = DELETED.LoadKey)
       WHERE LoadPlanLaneDetail.Trafficcop = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72706
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                          + ': Delete Trigger On Table LoadPlanLaneDetail Failed. (ntrLoadPlanDelete)'
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END -- tlting01 End

   -- (YokeBeen01) - Start
   -- Record has been triggered into CMSLOG with normal Status upon the last LoadplanDetail line is to be purged.
   -- This record will be updated from CMSLOG.TransmitFlag from "0" to "2",
   -- when this Loadplan Header record is to be purged.
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT 1 FROM DELETED
                    JOIN CMSLOG WITH (NOLOCK) ON (DELETED.LoadKey = CMSLOG.Key1)
                   WHERE CMSLOG.TableName = 'LPCANCCMS' AND CMSLOG.TransmitFlag = '0')
      BEGIN
         UPDATE CMSLOG  
            SET TransmitFlag = '2'
           FROM DELETED
           JOIN CMSLOG ON (DELETED.LoadKey = CMSLOG.Key1)
          WHERE CMSLOG.TableName = 'LPCANCCMS' AND CMSLOG.TransmitFlag = '0'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))
                             + ': Unable to Update CMSLog Record, TableName = LPCANCCMS (ntrLoadPlanDelete)'
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END -- IF @n_err <> 0
      END -- IF Key EXISTS and CMSLOG.TableName = 'LPCANCCMS'
   END -- IF @n_continue = 1 or @n_continue = 2
   -- (YokeBeen01) - End

   -- Start (KHLim01)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility
                           NULL,             -- Storerkey
                           NULL,             -- Sku
                           'DataMartDELLOG', -- Configkey
                           @b_success     OUTPUT,
                           @c_authority   OUTPUT,
                           @n_err         OUTPUT,
                           @c_errmsg      OUTPUT
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrLoadPlanDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.LoadPlan_DELLOG ( LoadKey )
         SELECT LoadKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrLoadPlanDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01)

   /* #INCLUDE <TRMBOHD2.SQL> */
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrLoadPlanDelete'
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