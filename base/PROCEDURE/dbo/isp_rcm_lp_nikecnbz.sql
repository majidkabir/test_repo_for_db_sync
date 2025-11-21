SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RCM_LP_NikeCNBZ                                */
/* Creation Date: 09-Apr-2018                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-4361-Load Plan RCM trigger CN-Nike pickdetail interface */
/*                                                                      */
/* Called By: Load Plan Dymaic RCM configure at listname 'RCMConfig'    */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Sep-2019  WLChooi   1.1   WMS-10618 - New Tablename - ALLOCLP2LOG */
/*                              (WL01)                                  */ 
/* 08-Apr-2020  WLChooi   1.2   WMS-12756 - New Tablename - ALLOCLP3LOG */
/*                              (WL02)                                  */ 
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_LP_NikeCNBZ]
   @c_Loadkey  NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_Facility NVARCHAR(5),
           @c_storerkey NVARCHAR(15)
           
   DECLARE @c_trmlogkey NVARCHAR(10)

   --WL01 Start
   DECLARE @c_Tablename NVARCHAR(30)

   CREATE TABLE #TableName(
   Tablename    NVARCHAR(30) )

   INSERT INTO #TableName
   SELECT 'ALLOCLPLOG'
   UNION ALL 
   SELECT 'ALLOCLP2LOG'
   UNION ALL              --WL02
   SELECT 'ALLOCLP3LOG'   --WL02
   --WL01 End
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Facility  = Facility,
                @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Loadkey = @c_Loadkey    
   
   --EXEC dbo.ispGenTransmitLog3 'ALLOCLPLOG', @c_Loadkey, @c_Facility, @c_StorerKey, ''  
   --     , @b_success OUTPUT  
   --     , @n_err OUTPUT  
   --     , @c_errmsg OUTPUT  
   
   --WL01 Start
   DECLARE Cur_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Tablename
   FROM #TableName

   OPEN Cur_Loop

   FETCH NEXT FROM Cur_Loop INTO @c_Tablename

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   --WL01 End
      SELECT @b_success = 1
      EXECUTE nspg_getkey
      -- Change by June 15.Jun.2004
      -- To standardize name use in generating transmitlog3..transmitlogkey
      -- 'Transmitlog3Key'
      'TransmitlogKey3'
      , 10
      , @c_trmlogkey OUTPUT
      , @b_success   OUTPUT
      , @n_err       OUTPUT
      , @c_errmsg    OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Obtain transmitlogkey. (isp_RCM_LP_NikeCNBZ)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE
      BEGIN
         INSERT INTO Transmitlog3 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
         VALUES (@c_trmlogkey, @c_Tablename, @c_Loadkey, @c_Facility, @c_StorerKey, '0', '')   --WL01
         
         --WL01 Start
         --UPDATE Loadplan
         --SET UserDefine01 = 'Y'
         --WHERE loadkey = @c_Loadkey 
         
         --SET @n_err = @@ERROR

         --IF @n_err <> 0
         --BEGIN
         --   SET @n_Continue = 3
         --END

         SET @n_err = @@ERROR

         --WL01 End
      END
        
      IF @b_success = 0
         SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_LP_NikeCNBZ: ' + rtrim(@c_errmsg)

      --WL01 Start
      FETCH NEXT FROM Cur_Loop INTO @c_Tablename
   END
   CLOSE Cur_Loop
   DEALLOCATE Cur_Loop
   
   IF @n_err = 0 AND @b_success = 1
   BEGIN
      UPDATE Loadplan
      SET UserDefine01 = 'Y'
      WHERE loadkey = @c_Loadkey 
   END
   --WL01 End

ENDPROC: 
 
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
  	    execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_LP_NikeCNBZ'
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
END -- End PROC


GO