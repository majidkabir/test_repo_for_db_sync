SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_SplitLoad                                                    */
/* Creation Date: 20th Jun 2007                                         */
/* Copyright: IDS                                                       */
/* Written by: SHONG SOS#73815                                          */
/*                                                                      */
/* Purpose: Split 1 Loadplan into Multiple Loadplan by Consignee        */
/*          The Original Load# will update to Loadplan.UserDefine09     */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Exceed Load plan screen                                   */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_SplitLoad]
   @c_LoadKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ConsigneeKey NVARCHAR(15),
            @c_NewLoadKey  NVARCHAR(10),
            @n_LineNo      int,
            @c_LineNo      NVARCHAR(5),
            @n_err         int,
            @c_errmsg      NVARCHAR(255),
            @b_success     int,
            @c_loadline    NVARCHAR(5),
            @c_OrderKey    NVARCHAR(10),
	         @d_TtlGrossWgt decimal,
            @d_ttlcube     decimal,
            @n_ttlcasecnt  int,
            @n_nooflines   int,
            @c_Status      NVARCHAR(10)
	,			@n_cnt         int
	,        @n_continue    int                 
	,        @n_starttcnt   int                -- Holds the current transaction count

   ,        @c_ExternOrderKey NVARCHAR(50)  --tlting_ext
   ,        @c_CustomerName   NVARCHAR(45)
   ,        @c_Facility       NVARCHAR(5)
   ,        @c_LoadLineNumber NVARCHAR(5)
   ,        @n_PalletCnt      int 
   ,        @n_CaseCnt        int 
   
	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

	BEGIN TRAN 
	
	-- Start : SOS33218
	IF @n_continue = 1 or @n_continue=2
	BEGIN 
      IF EXISTS(SELECT 1 FROM LOADPLANDETAIL lp WITH (NOLOCK) 
                WHERE lp.LoadKey = @c_LoadKey AND (lp.ConsigneeKey = '' or lp.ConsigneeKey IS NULL))
      BEGIN 
   	   UPDATE LOADPLANDETAIL 
   	   SET TrafficCop = '9',
   	       ConsigneeKey = O.ConsigneeKey
   	   FROM LOADPLANDETAIL  
         JOIN ORDERS O WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = O.OrderKey
   	   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
   	     AND (LOADPLANDETAIL.ConsigneeKey = '' OR LOADPLANDETAIL.ConsigneeKey is null)
   
   		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   		IF @n_err <> 0
   		BEGIN
   			SELECT @n_continue = 3
   			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69702   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
   			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLANDETAIL. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   		END
      END 
	END 

	IF @n_continue = 1 or @n_continue=2
	BEGIN
      DECLARE @NewLoadPlan 
         TABLE(LoadKey       NVARCHAR(10), 
               ConsigneeKey  NVARCHAR(15),
               Facility      NVARCHAR(5)) 

      INSERT INTO @NewLoadPlan (LoadKey, ConsigneeKey, Facility)
      SELECT DISTINCT LOADPLANDETAIL.LoadKey, LOADPLANDETAIL.ConsigneeKey, LOADPLAN.Facility 
      FROM   LOADPLANDETAIL WITH (NOLOCK) 
      JOIN   LOADPLAN WITH (NOLOCK) ON LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey 
      WHERE  LOADPLAN.UserDefine09 = @c_LoadKey 

      INSERT INTO @NewLoadPlan (LoadKey, ConsigneeKey, Facility) 
      SELECT DISTINCT '', LOADPLANDETAIL.ConsigneeKey, LoadPlan.Facility 
      FROM  LOADPLANDETAIL WITH (NOLOCK) 
      JOIN  LoadPlan WITH (NOLOCK) ON  LoadPlan.LoadKey = LOADPLANDETAIL.LoadKey 
      LEFT OUTER JOIN @NewLoadPlan NLP ON NLP.ConsigneeKey = LOADPLANDETAIL.ConsigneeKey 
	   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey 
      AND   NLP.LoadKey IS NULL 
      

      DECLARE C_ConsigneeKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT ConsigneeKey, Facility 
         FROM  @NewLoadPlan  
	      WHERE LoadKey = ''
         ORDER BY ConsigneeKey 

      OPEN C_ConsigneeKey 

      FETCH NEXT FROM C_ConsigneeKey INTO @c_ConsigneeKey, @c_Facility 

      WHILE @@FETCH_STATUS <> -1
      BEGIN
			SELECT @b_success = 0
	      EXECUTE nspg_GetKey
	         'LoadKey',
	         10,   
	         @c_NewLoadKey OUTPUT,
	         @b_success OUTPUT,
	         @n_err OUTPUT,
	         @c_errmsg OUTPUT

			IF @b_success = 1
	      BEGIN 
            UPDATE @NewLoadPlan SET LoadKey = @c_NewLoadKey WHERE ConsigneeKey = @c_ConsigneeKey 

	         INSERT LoadPlan (Facility, LoadKey, Userdefine09)
   	      VALUES ( @c_Facility, @c_NewLoadKey, @c_LoadKey )

				SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
					SELECT @n_continue = 3
					SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69703   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
					SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table LoadPlan. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
				END
	      END 
			ELSE
			BEGIN
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69704   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
				SELECT @c_errmsg = 'LoadKey Generation Failed. (isp_SplitLoad)'
			END

         FETCH NEXT FROM C_ConsigneeKey INTO @c_ConsigneeKey, @c_Facility 
      END
      CLOSE C_ConsigneeKey
      DEALLOCATE C_ConsigneeKey 
   
      DECLARE C_ConsigneeLoad CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LoadKey, ConsigneeKey 
         FROM   @NewLoadPlan 
         ORDER BY LoadKey 
   		      
      OPEN C_ConsigneeLoad
   
      FETCH NEXT FROM C_ConsigneeLoad INTO @c_NewLoadKey, @c_ConsigneeKey  
      WHILE @@FETCH_STATUS <> -1
      BEGIN 
         SET @n_LineNo = 0 

         DECLARE C_ConsigneeLoadLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LoadLineNumber, OrderKey 
            FROM   LOADPLANDETAIL WITH (NOLOCK) 
            WHERE  LoadKey = @c_LoadKey 
            AND    ConsigneeKey = @c_ConsigneeKey 
            ORDER BY LoadLineNumber 

         OPEN C_ConsigneeLoadLine

         FETCH NEXT FROM C_ConsigneeLoadLine INTO @c_LoadLineNumber, @c_OrderKey 

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @n_LineNo = @n_LineNo + 1
	   		SELECT @c_LineNo = dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(4), @n_LineNo)))  
	   		SELECT @c_LineNo = REPLICATE('0', 5 - LEN(@c_LineNo)) + dbo.fnc_RTrim(@c_LineNo)

            -- select @c_NewLoadKey '@c_NewLoadKey', @c_LineNo '@c_LineNo', @c_LoadLineNumber '@c_LoadLineNumber'

            UPDATE LOADPLANDETAIL WITH (ROWLOCK) 
               SET LoadKey        = @c_NewLoadKey, 
                   LoadLineNumber = @c_LineNo, 
                   TrafficCop = NULL
            WHERE LoadKey = @c_LoadKey 
            AND   LoadLineNumber = @c_LoadLineNumber
				SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
					SELECT @n_continue = 3
					SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69707   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
					SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLANDETAIL. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
				END

				IF @n_continue = 1 or @n_continue=2
				BEGIN
		         UPDATE ORDERDETAIL WITH (ROWLOCK) 
		            SET TrafficCop = null,
		                LoadKey = @c_NewLoadKey
		         WHERE OrderKey = @c_OrderKey
		           AND LoadKey  = @c_LoadKey
          
					SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
					IF @n_err <> 0
					BEGIN
						SELECT @n_continue = 3
						SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69707   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
						SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
					END
				END


				IF @n_continue = 1 or @n_continue=2
				BEGIN
		         UPDATE ORDERS WITH (ROWLOCK) 
		            SET TrafficCop = null,
		                LoadKey = @c_NewLoadKey
		         WHERE OrderKey = @c_OrderKey
		           AND LoadKey  = @c_LoadKey
          
					SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
					IF @n_err <> 0
					BEGIN
						SELECT @n_continue = 3
						SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69707   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
						SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
					END
				END

            FETCH NEXT FROM C_ConsigneeLoadLine INTO @c_LoadLineNumber, @c_OrderKey 
         END
         CLOSE C_ConsigneeLoadLine
         DEALLOCATE C_ConsigneeLoadLine

   		IF @n_continue = 1 or @n_continue=2
   		BEGIN
   	      -- finalize and update the status of the new LoadPlan
   	      select @c_status = MIN(status)
   	      from LOADPLANDETAIL WITH (NOLOCK)
   	      where LoadKey = @c_NewLoadKey
   
	         SELECT @d_ttlgrosswgt = SUM(ORDERDETAIL.qtypicked * SKU.StdGrossWgt),
					    @d_ttlcube = SUM(ORDERDETAIL.qtypicked * SKU.StdCube),
					    @n_ttlcasecnt = SUM( CASE WHEN PACK.CaseCnt = 0 THEN 0
				  		                           ELSE (ORDERDETAIL.OpenQty / PACK.CaseCnt) END ),
					    @n_nooflines = COUNT(ORDERDETAIL.OrderKey), 
                   @n_PalletCnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
                		                                 ELSE (ORDERDETAIL.OpenQty / PACK.Pallet) END)), 
                   @n_CaseCnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
   				                                     ELSE (ORDERDETAIL.OpenQty / PACK.CaseCnt) END)) 
				FROM ORDERDETAIL WITH (NOLOCK) 
				JOIN SKU WITH (NOLOCK)	on ORDERDETAIL.StorerKey = SKU.StorerKey
	                          and ORDERDETAIL.SKU = SKU.SKU
	         JOIN PACK WITH (NOLOCK) on PACK.PackKey = SKU.PackKey 
	         WHERE ORDERDETAIL.LoadKey = @c_LoadKey		

   	      UPDATE LoadPlan WITH (ROWLOCK) 
   	      SET LoadPlan.finalizeflag = 'Y',
   	          LoadPlan.status = @c_status, 
                LoadPlan.CustCnt   = 1, 
                LoadPlan.OrderCnt  = LoadPlan.OrderCnt + 1,
                LoadPlan.Weight    = @d_ttlgrosswgt,
                LoadPlan.Cube      = @d_ttlcube,
                LoadPlan.PalletCnt = @n_PalletCnt,
                LoadPlan.CaseCnt   = @n_CaseCnt, 
                LoadPlan.TrafficCop = NULL 
   	      WHERE LoadKey = @c_NewLoadKey

   	      select @n_err = @@error
   
   			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   			IF @n_err <> 0
   			BEGIN
   				SELECT @n_continue = 3
   				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69708   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
   				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlan. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   			END
   		END

         FETCH NEXT FROM C_ConsigneeLoad INTO @c_NewLoadKey, @c_ConsigneeKey         
      END 
      CLOSE C_ConsigneeLoad
      DEALLOCATE C_ConsigneeLoad

	   IF NOT EXISTS (SELECT 1 FROM LoadPlan WITH (NOLOCK) WHERE LoadKey = @c_LoadKey)
	   BEGIN
	      UPDATE LoadPlan
	         set ArchiveCop = '9'
	      WHERE LoadKey = @c_LoadKey
			
			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69711   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlan. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
			END

			IF @n_continue = 1 or @n_continue=2
			BEGIN	
				delete LoadPlan
	         where  LoadKey = @c_LoadKey
				SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
					SELECT @n_continue = 3
					SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69712   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
					SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Failed On Table LoadPlan. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
				END
			END
		END -- SOS33218

		-- Start : SOS33218
		IF @n_continue = 1 or @n_continue=2
		BEGIN
		-- End : SOS33218				
			if exists (select 1 from ORDERDETAIL (nolock) where LoadKey = @c_LoadKey)
			begin
				-- SOS33218
				-- begin tran
				update od
				set od.TrafficCop = null,
					 od.LoadKey = ld.LoadKey
				from ORDERDETAIL od 
				join LOADPLANDETAIL ld WITH (NOLOCK) on od.OrderKey = ld.OrderKey
				where od.LoadKey = @c_LoadKey
		
				SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
					SELECT @n_continue = 3
					SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69713   -- Should Be Set To The SQL Errmessage but I don't know how to do sO.
					SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_SplitLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
				END
				-- End : SOS33218
			end
		END -- SOS33218
	END -- Continue = '1' or '2'

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
		execute nsp_logerror @n_err, @c_errmsg, 'isp_SplitLoad'
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