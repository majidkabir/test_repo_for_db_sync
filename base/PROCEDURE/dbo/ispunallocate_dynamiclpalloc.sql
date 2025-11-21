SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispUnallocate_DynamicLPAlloc                       */
/* Creation Date: 07-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: CN NIKE Bridge - Unallocate Dynamic LoadPlan Allocation     */
/*                                                                      */
/* Input Parameters:  @c_Storerkey   NVARCHAR(15)  					            */
/*							,@c_loadkey          NVARCHAR(10)				            */
/*							,@c_sku              NVARCHAR(20)				            */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes												*/
/* 02-12-2008   wwang       row 298, add status in('3','4','6')         */
/* 03-12-2008   wwang       add Storerkey as parameter                  */
/* 29-04-2011   Leong       SOS# 213836 - Delete unprocess DRP task.    */
/* 10-11-2011   TLTING      Performance Tune                            */
/************************************************************************/

CREATE PROC  [dbo].[ispUnallocate_DynamicLPAlloc]
   @c_Storerkey NVARCHAR(15),
   @c_LoadKey  NVARCHAR(10),
   @c_SKU      NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_continue  int,  /* continuation flag
                           1=Continue
                           2=failed but continue processsing
                           3=failed do not continue processing
                           4=successful but skip furthur processing */
      @n_starttcnt int, -- Holds the current transaction count
      @b_success   int,
      @n_err       int,
      @c_errmsg    NVARCHAR(250),
      @b_debug     int

   DECLARE
      @c_PickSlipNo NVARCHAR(10),
      @n_SKUCnt     int
   DECLARE @c_UCCNo	 NVARCHAR(20),
     @c_ReplenishmentKey NVARCHAR(10),
     @c_PickdetailKey	 NVARCHAR(10),
     @c_TaskDetailKey      NVARCHAR(10),
     @c_CurSKU             NVARCHAR(20)

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @b_debug=0

   BEGIN TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Check blank LoadKey
      IF ISNULL(RTRIM(@c_LoadKey), '') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63001
         SELECT @c_errmsg = 'Empty LoadKey (ispUnallocate_DynamicLPAlloc)'
         GOTO RETURN_SP
      END

      -- Check LoadKey exists
       IF NOT EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK)
                     WHERE LoadKey = @c_LoadKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63002
         SELECT @c_errmsg = 'LoadKey Not Found (ispUnallocate_DynamicLPAlloc)'
         GOTO RETURN_SP
      END

       -- Check LoadKey closed
       IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK)
                  WHERE LoadKey = @c_LoadKey
                  AND   Status = '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63003
         SELECT @c_errmsg = 'LoadKey Closed (ispUnallocate_DynamicLPAlloc)'
         GOTO RETURN_SP
      END

      -- Any allocation
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
                     WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
                     AND   OH.Storerkey = @c_Storerkey
                     AND   PD.Status='0' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63004
         SELECT @c_errmsg = 'No Order to Unallocate (ispUnallocate_DynamicLPAlloc)'
         GOTO RETURN_SP
      END

      -- Check if Pack Confirmed
      IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                 INNER JOIN PACKHEADER PACHD (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey )
                 WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
                 AND   isnull(PACHD.Loadkey,'')<>''
                 AND   OH.Storerkey = @c_Storerkey
                 AND   PACHD.Status = '9' ) -- Pack Confirmed
       BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'Pack Confirmed. Unallocation is Not Allowed (ispUnallocate_DynamicLPAlloc)'
         GOTO RETURN_SP
      END

      -- If SKU not blank
      IF ISNULL(RTRIM(@c_SKU),'') <> ''
      BEGIN
         -- Check if SKU exists in LOAD
         IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                        INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
                        WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
                        AND   OH.Storerkey = @c_Storerkey
                        AND   OD.SKU = @c_SKU)
        BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63006
            SELECT @c_errmsg = 'SKU Not Found in Load (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END

         -- Check if SKU exists in PICKDETAIL
         IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                        INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey )
                        WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
                        AND   OH.Storerkey = @c_Storerkey
                        AND   PD.SKU = @c_SKU)
        BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63007
            SELECT @c_errmsg = 'SKU Not Allocated (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END

         -- Check if one or multiple SKU
         SET @n_SKUCnt = 0
         SELECT @n_SKUCnt = COUNT( DISTINCT OD.SKU)
         FROM ORDERS OH WITH (NOLOCK)
         INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
         WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
         AND   OH.Storerkey = @c_Storerkey

         IF @n_SKUCnt = 1
         BEGIN
            -- Only 1 SKU in Load, treat as unallocate whole Load
            SET @c_SKU = ''
         END
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END 
      
  --    DECLARE @tTempRESULT TABLE (  
      CREATE TABLE #TempRESULT(
         ROWREF            INT IDENTITY(1,1) NOT NULL Primary Key,
         GroupType          NVARCHAR(30) NULL,
         SKU                NVARCHAR(20) NULL,
         QTY                INT      NULL,
         LOC                NVARCHAR(10) NULL,
         ID                 NVARCHAR(18) NULL,
         CartonNo           INT      NULL,
         UCCNo              NVARCHAR(20) NULL,
         ReplenishmentGroup NVARCHAR(10) NULL)

      -- If NULL set SKU to blank
      IF ISNULL(RTRIM(@c_SKU),'') = ''
         SET @c_SKU = ''

      -- Get PickSlipNo
      SET ROWCOUNT 1

      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = PickHeaderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE ExternOrderKey = @c_LoadKey AND ExternOrderKey IS NOT NULL

      -- If NULL set PickSlipNo to blank
      IF @c_PickSlipNo IS NULL
         SET @c_PickSlipNo = ''

      SET ROWCOUNT 0

      /* ----------------------------------------------- */
      /* INSERT Result Set                               */
      /* ----------------------------------------------- */
      -- GROUP1. PICKDETAIL
      INSERT INTO #TempRESULT  (GroupType, SKU, QTY, LOC, ID, CartonNo, UCCNo, ReplenishmentGroup )
      SELECT 'PICKDETAIL Group', SKU, QTY, LOC, ID, 0, '', ''
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey =@c_STorerkey)
      WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
      AND   PD.SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE PD.SKU END
      AND   OH.Storerkey = @c_Storerkey
      ORDER BY LOC, PD.SKU

      -- GROUP2. PACKDETAIL
      INSERT INTO #TempRESULT  (GroupType, SKU, QTY, LOC, ID, CartonNo, UCCNo, ReplenishmentGroup )
      SELECT 'PACKDETAIL Group', SKU, QTY, '', '', CartonNo, '', ''
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   Storerkey = @c_STorerkey
      AND   SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE SKU END
      ORDER BY CartonNo, SKU

      -- GROUP3. UCC
      INSERT INTO #TempRESULT  (GroupType, SKU, QTY, LOC, ID, CartonNo, UCCNo, ReplenishmentGroup )
      SELECT 'UCC Group', SKU, QTY, FromLoc, ID, 0, RefNo, ReplenishmentGroup
      FROM REPLENISHMENT WITH (NOLOCK)
      WHERE LoadKey = @c_LoadKey AND LoadKey IS NOT NULL
      AND   Storerkey = @c_Storerkey
      AND   ToLoc = 'PICK' -- FCP
      AND   SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE SKU END
      ORDER BY FromLoc, SKU

      /* ----------------------------------------------- */
      /* START UNALLOCATION                              */
      /* ----------------------------------------------- */
      -- 1. UPDATE UCC
	   DECLARE Cursor_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCCNo
         FROM UCC UCC WITH (NOLOCK)
         INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (UCC.UCCNo = RPL.RefNo AND RPL.Storerkey = @c_Storerkey)
         WHERE RPL.LoadKey = @c_LoadKey AND RPL.LoadKey  IS NOT NULL
         AND   UCC.Storerkey = @c_Storerkey
         AND   isnull(RPL.RefNo,'')<>''
         AND   RPL.ToLoc = 'PICK' -- FCP
         AND   UCC.Status IN ('3','4','6')
         AND   UCC.SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE UCC.SKU END
		   
	   OPEN Cursor_UCC 
		   
	   FETCH NEXT FROM Cursor_UCC INTO @c_UCCNo
	   WHILE @@FETCH_STATUS <> -1
	   BEGIN   
	   	BEGIN TRAN   
  
         UPDATE UCC WITH (ROWLOCK) SET
            Status = '1',
            UserDefined01 = '',
   			EditDate = GETDATE(),
   			EditWho = sUSER_sNAME()
         FROM UCC UCC
		    WHERE UCC.UCCNo = UCC.UCCNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63013
            SELECT @c_errmsg = 'UPDATE UCC failed (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  		    

	      FETCH NEXT FROM Cursor_UCC INTO @c_UCCNo
	   END
	   CLOSE Cursor_UCC 
	   DEALLOCATE Cursor_UCC 

      -- 2. DELETE REPLENISHMENT

	   DECLARE Cursor_REP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   	SELECT ReplenishmentKey
      FROM REPLENISHMENT WITH (NOLOCK) -- SOS# 178258
      WHERE LoadKey = @c_LoadKey AND LoadKey IS NOT NULL
      AND   Storerkey = @c_Storerkey
      AND   ToLoc = 'PICK' -- FCP
      AND   SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE SKU END	   
	   OPEN Cursor_REP 
		   
	   FETCH NEXT FROM Cursor_REP INTO @c_ReplenishmentKey
	   WHILE @@FETCH_STATUS <> -1
	   BEGIN   
	   	BEGIN TRAN   
      	   	 	      
	      DELETE REPLENISHMENT WITH (ROWLOCK) 
	      WHERE  ReplenishmentKey = @c_ReplenishmentKey
	      IF @@ERROR <> 0
	      BEGIN
	         SELECT @n_continue = 3
	         SELECT @n_err = 63008
	         SELECT @c_errmsg = 'DELETE REPLENISHMENT failed (ispUnallocate_DynamicLPAlloc)'
	         GOTO RETURN_SP
	      END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  		    

	      FETCH NEXT FROM Cursor_REP INTO @c_ReplenishmentKey
	   END
	   CLOSE Cursor_REP 
	   DEALLOCATE Cursor_REP   
	   	         
	   DECLARE Cursor_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   	SELECT PACDT.SKU
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
      INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
      WHERE PACDT.PickSlipNo  = @c_PickSlipNo
	   OPEN Cursor_PACKDETAIL 
		   
	   FETCH NEXT FROM Cursor_PACKDETAIL INTO @c_CurSKU
	   WHILE @@FETCH_STATUS <> -1
	   BEGIN   
	   	BEGIN TRAN   
	   	  	      
	      DELETE PACKDETAIL WITH (ROWLOCK) -- SOS# 178258
	      WHERE PickSlipNo = @c_PickSlipNo
	      AND SKU =  @c_CurSKU
	      IF @@ERROR <> 0
	      BEGIN
	         SELECT @n_continue = 3
	         SELECT @n_err = 63009
	         SELECT @c_errmsg = 'DELETE PACKDETAIL failed (ispUnallocate_DynamicLPAlloc)'
	         GOTO RETURN_SP
	      END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END 	      
	      FETCH NEXT FROM Cursor_PACKDETAIL INTO @c_CurSKU
	   END
	   CLOSE Cursor_PACKDETAIL 
	   DEALLOCATE Cursor_PACKDETAIL  

      -- PACKDETAIL is Empty
      IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo)
      BEGIN
         BEGIN TRAN
         -- 3. DELETE PACKHEADER
         DELETE PACKHEADER with (RowLock)
         WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63010
            SELECT @c_errmsg = 'DELETE PACKHEADER failed (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END          
      END


      -- 3. DELETE PICKDETAIL      
	   DECLARE Cursor_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   	SELECT PD.PickdetailKey
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey )
      WHERE OH.LoadKey = @c_LoadKey AND OH.LoadKey IS NOT NULL
      AND   OH.Storerkey = @c_Storerkey
      AND   PD.SKU = CASE WHEN @c_SKU <> '' THEN @c_SKU ELSE PD.SKU END	   	
	   	
	   OPEN Cursor_PICKDETAIL 
		   
	   FETCH NEXT FROM Cursor_PICKDETAIL INTO @c_PickdetailKey
	   WHILE @@FETCH_STATUS <> -1
	   BEGIN   
    	   BEGIN TRAN   

	      DELETE PICKDETAIL WITH (ROWLOCK) -- SOS# 178258
	      WHERE PickdetailKey = @c_PickdetailKey
	      IF @@ERROR <> 0
	      BEGIN
	         SELECT @n_continue = 3
	         SELECT @n_err = 63010
	         SELECT @c_errmsg = 'DELETE PICKDETAIL failed (ispUnallocate_DynamicLPAlloc)'
	         GOTO RETURN_SP
	      END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  		    

	      FETCH NEXT FROM Cursor_PICKDETAIL INTO @c_PickdetailKey
	   END
	   CLOSE Cursor_PICKDETAIL 
	   DEALLOCATE Cursor_PICKDETAIL
      	   
      -- PICKDETAIL is Empty
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey )
                     WHERE OH.Storerkey = @c_Storerkey 
                     AND OH.LoadKey = @c_LoadKey AND OH.LoadKey is NOT NULL )
                                                      --isnull(OH.LoadKey,'') = @c_LoadKey )
      BEGIN
         BEGIN TRAN
         -- 5. DELETE PICKINGINFO
         DELETE PICKINGINFO with (RowLock)
         WHERE PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63012
            SELECT @c_errmsg = 'DELETE PICKINGINFO failed (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END     
                  
         BEGIN TRAN
         -- 4. DELETE PICKHEADER
         DELETE PICKHEADER with (RowLock)
         WHERE PickHeaderKey = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63011
            SELECT @c_errmsg = 'DELETE PICKHEADER failed (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END           
      
      END

	   DECLARE Cursor_TaskDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   	SELECT TaskDetailKey
	   	FROM TASKDETAIL WITH (ROWLOCK)
         WHERE TaskType = 'DRP'
         AND Status = '0'
         AND LoadKey = @c_LoadKey
         AND StorerKey = @c_Storerkey

	   OPEN Cursor_TaskDetail 
		   
	   FETCH NEXT FROM Cursor_TaskDetail INTO @c_TaskDetailKey
	   WHILE @@FETCH_STATUS <> -1
	   BEGIN   
	   	BEGIN TRAN 
	   	  -- SOS# 213836 
         DELETE TASKDETAIL WITH (ROWLOCK)
         WHERE TaskType = 'DRP'
         AND Status = '0'
         AND LoadKey = @c_LoadKey
         AND StorerKey = @c_Storerkey
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63015
            SELECT @c_errmsg = 'DELETE Dynamic Replenishment TaskDetail failed (ispUnallocate_DynamicLPAlloc)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  	         

	      FETCH NEXT FROM Cursor_TaskDetail INTO @c_TaskDetailKey
	   END
	   CLOSE Cursor_TaskDetail 
	   DEALLOCATE Cursor_TaskDetail  

      /* ----------------------------------------------- */
      /* RETURN Result Set                               */
      /* ----------------------------------------------- */
      SELECT GroupType, SKU, QTY, LOC, ID, CartonNo, UCCNo, ReplenishmentGroup
      FROM #TempRESULT

   END -- IF @n_continue = 1 OR @n_continue = 2

   WHILE @@TRANCOUNT<@n_starttcnt 
      BEGIN TRAN 
         
   RETURN_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispUnallocate_DynamicLPAlloc'
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