SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_ReplenishToFPA_Order_Summary                   */
/* Creation Date: 26-Dec-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#62931 - Replensihment Report for IDSHK LOR principle    */
/*          - Replenish To Forward Pick Area (FPA)                      */
/*          - Printed together with Move Ticket & Pickslip in a         */
/*            composite report                                          */
/*                                                                      */
/* Called By: RCM - Popup Pickslip in Loadplan / WavePlan               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 05 Mar 2007  jwong     fix bug                                       */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */  
/************************************************************************/
CREATE PROC  [dbo].[nsp_ReplenishToFPA_Order_Summary]
             @c_Key_Type  NVARCHAR(13)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   ,               @n_starttcnt   int


   DECLARE @b_debug   int,
           @b_success int,
           @n_err     int,
           @c_errmsg  NVARCHAR(255)

   SELECT @n_continue=1, @b_debug = 0

      
   DECLARE @c_ExternOrderkey NVARCHAR(50),  --tlting_ext 
           @c_OrderKey       NVARCHAR(10),
           @n_Count          int,
           @n_TotalOrd       int,
           @n_TotalIN        int,
           @n_TotalDN        int,
           @n_TotalTN        int

   DECLARE @n_TotalOrd1      int,
           @n_TotalOrd2      int,
           @n_TotalOrd3      int,
           @n_TotalOrd4      int,
           @n_TotalOrd5      int,
           @n_TotalIN1       int,
           @n_TotalIN2       int,
           @n_TotalIN3       int,
           @n_TotalIN4       int,
           @n_TotalIN5       int,
           @n_TotalDN1       int,
           @n_TotalDN2       int,
           @n_TotalDN3       int,
           @n_TotalDN4       int,
           @n_TotalDN5       int,
           @n_TotalTN1       int,
           @n_TotalTN2       int,
           @n_TotalTN3       int,
           @n_TotalTN4       int,
           @n_TotalTN5       int

   DECLARE @c_Key            NVARCHAR(10),
           @c_Type           NVARCHAR(2)

   SELECT @c_Key = LEFT(@c_Key_Type, 10)
   SELECT @c_Type = RIGHT(@c_Key_Type,2)
 
   SELECT @n_Count = 1

   SELECT  @n_TotalOrd = 0,
           @n_TotalIN  = 0,
           @n_TotalDN  = 0,
           @n_TotalTN  = 0

   SELECT  @n_TotalOrd1 = 0,
			  @n_TotalOrd2 = 0,
			  @n_TotalOrd3 = 0,
           @n_TotalIN1  = 0,
           @n_TotalIN2  = 0,
           @n_TotalIN3  = 0,
           @n_TotalDN1  = 0,
           @n_TotalDN2  = 0,
           @n_TotalDN3  = 0,
           @n_TotalTN1  = 0,
           @n_TotalTN2  = 0,           
           @n_TotalTN3  = 0

   CREATE TABLE #TEMPORDERS  (Temp1      NVARCHAR(30) NULL,
										Temp2      NVARCHAR(30) NULL,
										Temp3      NVARCHAR(30) NULL)

   IF @c_Type = 'WP'
   BEGIN
	  	DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	   SELECT DISTINCT ORDERS.ExternOrderkey
	   FROM WAVEDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE WAVEKEY = @c_Key
	   Order By ORDERS.ExternOrderkey
	   
		OPEN C_CUR
		
		FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey
		
		WHILE @@FETCH_STATUS <> -1 
		BEGIN

         IF @b_debug = 1
         BEGIN
            Print '@c_Type: '+ @c_Type 
            SELECT '@c_ExternOrderkey', @c_ExternOrderkey, '@n_Count', @n_Count
         END

         IF @n_Count = 1
         BEGIN
            INSERT INTO #TEMPORDERS (Temp1, Temp2, Temp3)
            SELECT @c_ExternOrderkey, 'N', 'N'
         END
         ELSE IF @n_Count = 2
         BEGIN
            UPDATE #TEMPORDERS 
              SET Temp2 = @c_ExternOrderkey
            WHERE Temp2 = 'N'
         END
         ELSE IF @n_Count = 3
         BEGIN
            UPDATE #TEMPORDERS 
              SET Temp3 = @c_ExternOrderkey
            WHERE Temp3 = 'N'
         END

         SELECT @n_Count = @n_Count + 1
         IF @n_Count > 3
         BEGIN
            SELECT @n_Count = 1
         END

         IF @b_debug = 1
         BEGIN
            SELECT @n_Count ' @n_Count', @c_ExternOrderkey ' @c_ExternOrderkey'
         END


	   FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey
	 END -- While detail
	 CLOSE C_CUR
	 DEALLOCATE C_CUR
  END -- @c_Type = 'WV'
  ELSE IF @c_Type = 'LP'
  BEGIN
	  	DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	   SELECT DISTINCT ORDERS.ExternOrderkey
	   FROM LOADPLANDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE LOADPLANDETAIL.LOADKEY = @c_Key
	   Order By ORDERS.ExternOrderkey
	   
		OPEN C_CUR
		
		FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey
		
		WHILE @@FETCH_STATUS <> -1 
		BEGIN

         IF @b_debug = 1
         BEGIN
            Print '@c_Type: '+ @c_Type 
            SELECT '@c_ExternOrderkey', @c_ExternOrderkey, '@n_Count', @n_Count
         END

         IF @n_Count = 1
         BEGIN
            INSERT INTO #TEMPORDERS (Temp1, Temp2, Temp3)
            SELECT @c_ExternOrderkey, 'N', 'N'
         END
         ELSE IF @n_Count = 2
         BEGIN
            UPDATE #TEMPORDERS 
              SET Temp2 = ISNULL(@c_ExternOrderkey, '')
            WHERE Temp2 = 'N'
         END
         ELSE IF @n_Count = 3
         BEGIN
            UPDATE #TEMPORDERS 
              SET Temp3 = ISNULL(@c_ExternOrderkey, '')
            WHERE Temp3 = 'N'
         END

         SELECT @n_Count = @n_Count + 1
         IF @n_Count > 3
         BEGIN
            SELECT @n_Count = 1
         END

         IF @b_debug = 1
         BEGIN
            SELECT @n_Count ' @n_Count', @c_ExternOrderkey ' @c_ExternOrderkey'
         END

	   FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey
	 END -- While detail
	 CLOSE C_CUR
	 DEALLOCATE C_CUR
  END -- @c_Type = 'LP'
  
  

  IF @n_continue=3  -- Error Occured - Process AND Return
  BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishToFPA_Order_Summary'
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
      -- RETURN
   END

   SELECT @n_TotalOrd1 = COUNT(Temp1)
   FROM #TEMPORDERS (NOLOCK)
   WHERE Temp1 <> 'N'

   SELECT @n_TotalOrd2 = COUNT(Temp2)
   FROM #TEMPORDERS (NOLOCK)
   WHERE Temp2 <> 'N'

   SELECT @n_TotalOrd3 = COUNT(Temp3)
   FROM #TEMPORDERS (NOLOCK)
   --WHERE Temp2 <> 'N'		--sos#70023 change temp2 to temp3
	WHERE Temp3 <> 'N'
	
   SELECT @n_TotalIN1 = COUNT(Temp1)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp1, 1, 2) = 'IN'

   SELECT @n_TotalIN2 = COUNT(Temp2)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp2, 1, 2) = 'IN'

   SELECT @n_TotalIN3 = COUNT(Temp3)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp3, 1, 2) = 'IN'

   SELECT @n_TotalDN1 = COUNT(Temp1)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp1, 1, 2) = 'DN'

   SELECT @n_TotalDN2 = COUNT(Temp2)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp2, 1, 2) = 'DN'

   SELECT @n_TotalDN3 = COUNT(Temp3)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp3, 1, 2) = 'DN'

   SELECT @n_TotalTN1 = COUNT(Temp1)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp1, 1, 2) = 'TN'

   SELECT @n_TotalTN2 = COUNT(Temp2)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp2, 1, 2) = 'TN'

   SELECT @n_TotalTN3 = COUNT(Temp3)
   FROM #TEMPORDERS (NOLOCK)
   WHERE SUBSTRING(Temp3, 1, 2) = 'TN'


   SELECT @n_TotalOrd = @n_TotalOrd1 + @n_TotalOrd2 + @n_TotalOrd3
   SELECT @n_TotalIN  = @n_TotalIN1  + @n_TotalIN2  + @n_TotalIN3
   SELECT @n_TotalDN  = @n_TotalDN1  + @n_TotalDN2  + @n_TotalDN3
   SELECT @n_TotalTN  = @n_TotalTN1  + @n_TotalTN2  + @n_TotalTN3

   SELECT ISNULL(Temp1, ''), 
          CASE WHEN Temp2 = 'N' THEN '' ELSE ISNULL(Temp2, '') END, 
          CASE WHEN Temp3 = 'N' THEN '' ELSE ISNULL(Temp3, '') END, 
          @c_Key, suser_sname(), @n_TotalOrd, @n_TotalIN, @n_TotalDN, @n_TotalTN
   FROM  #TEMPORDERS (NOLOCK)

   DROP TABLE #TEMPORDERS

END -- End of Proc

GO