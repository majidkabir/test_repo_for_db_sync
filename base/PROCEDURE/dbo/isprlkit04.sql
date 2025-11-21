SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLKIT04                                          */  
/* Creation Date: 26-Aug-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-10085 CN/SG Logitech split kitting                       */
/*          Storerconifg:	KitReleaseTask_SP  Option1 = Split to new kit */
/*                                                                       */  
/* Called By: Kitting RCM Release pick task (split to new kit)           */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 08-Jul-2020  NJOW01   1.0  WMS-14142 copy lottable07 to to-kit        */
/* 19-Nov-2021  WLChooi  1.1  DevOps Combine Script                      */
/* 19-Nov-2021  WLChooi  1.1  WMS-18400 - Filter by KITKey (WL01)        */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLKIT04]      
  @c_kitkey       NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
                
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0
            
    DECLARE @c_FinalLoc         NVARCHAR(10),
            @c_ExternKitKey     NVARCHAR(20),
            @n_MainQty          INT,
            @n_FinalQty         INT,
            @n_Qty              INT,
            @c_NewKitkey        NVARCHAR(10),
            @c_NewKitLineNumber NVARCHAR(5),
            @n_KitCnt           INT,
            @n_KitLineNumber    INT,
            @c_kitLineNumber    NVARCHAR(5),
            @c_Lottable01       NVARCHAR(18),    
            @c_Lottable02       NVARCHAR(18),    
            @c_Lottable03       NVARCHAR(18),    
            @d_Lottable04       DATETIME,    
            @d_Lottable05       DATETIME,  
            @c_Lottable06       NVARCHAR(30),       
            @c_Lottable07       NVARCHAR(30),       
            @c_Lottable08       NVARCHAR(30),       
            @c_Lottable09       NVARCHAR(30),       
            @c_Lottable10       NVARCHAR(30),       
            @c_Lottable11       NVARCHAR(30),       
            @c_Lottable12       NVARCHAR(30),       
            @d_Lottable13       DATETIME,     
            @d_Lottable14       DATETIME,     
            @d_Lottable15       DATETIME    
                                                                           
    -----Kit Validation-----                 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF NOT EXISTS (SELECT 1 FROM KIT (NOLOCK) 
                      WHERE Status IN('2','5')
                      AND actionflag IN('N','U')
                      AND Kitkey = @c_Kitkey)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Kit is not allowed to Split. Invalid status/actionflag (ispRLKIT04)'       
          GOTO RETURN_SP
       END                 
       
       IF NOT EXISTS (SELECT 1 FROM KITDETAIL (NOLOCK) 
                      WHERE Kitkey = @c_Kitkey
                      AND Type = 'F'
                      AND Qty > 0) 
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Kit has nothing to Split. (ispRLKIT04)'       
          GOTO RETURN_SP
       END             
       
       SELECT @c_FinalLoc = CL.Short
       FROM CODELKUP CL (NOLOCK)
       JOIN KIT (NOLOCK) ON CL.Code = KIT.Facility AND CL.Storerkey = KIT.Storerkey
       JOIN LOC (NOLOCK) ON CL.Short = LOC.Loc
       WHERE CL.ListName = 'LOGIKIT' 
       AND KIT.KITKey = @c_kitkey   --WL01
       
       IF ISNULL(@c_FinalLoc,'') = ''
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Kitting Final Loc setup at Listname LOGIKIT. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO RETURN_SP             	
       END                    
       
       IF EXISTS (SELECT 1
                  FROM KIT K (NOLOCK)
                  JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
                  LEFT JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
                  WHERE K.Kitkey = @c_KitKey
                  AND KD.Type = 'F'
                  AND KD.Lot IS NOT NULL
                  AND KD.Lot <> '' 
                  AND (SI.ExtendedField07 NOT IN ('M','S') OR SI.ExtendedField07 IS NULL)
                  --AND KD.Lottable02 IS NOT NULL
                  --AND KD.Lottable02 <> ''
                  AND KD.Qty > 0)                  
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83035
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Value at SKUINFO.ExtendedField07. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO RETURN_SP             	
       END       

       IF EXISTS (SELECT 1
                  FROM KIT K (NOLOCK)
                  JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
                  JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
                  WHERE K.Kitkey = @c_KitKey
                  AND KD.Type = 'F'
                  AND SI.ExtendedField07 = 'M' 
                  HAVING COUNT(DISTINCT KD.Sku) > 1)                  
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83036
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No more than one SKUINFO.ExtendedField07 = ''M'' is allowed in a Kit. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO RETURN_SP             	
       END
              
       SELECT @n_MainQty = ISNULL(SUM(KD.Qty),0)
       FROM KIT K (NOLOCK)
       JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
       JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
       WHERE K.Kitkey = @c_KitKey
       AND KD.Type = 'F'
       AND KD.Lot IS NOT NULL
       AND KD.Lot <> '' 
       AND SI.ExtendedField07 = 'M'
       AND KD.Lottable02 IS NOT NULL
       AND KD.Lottable02 <> ''
       AND KD.Qty > 0
       
       SELECT @n_FinalQty = ISNULL(SUM(KD.Qty),0)
       FROM KIT K (NOLOCK)
       JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
       WHERE K.Kitkey = @c_KitKey
       AND KD.Type = 'T'
       AND KD.Qty > 0
       
       IF @n_MainQty <> @n_FinalQty
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83037
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': From Main Qty ' + RTRIM(CAST(@n_MainQty AS NVARCHAR)) + ' is not tally with To Qty ' + RTRIM(CAST(@n_FinalQty AS NVARCHAR)) + ' (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO RETURN_SP             	       	
       END                               
    END       
             
    IF @@TRANCOUNT = 0
       BEGIN TRAN
       	
    --Split kit
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN                  	 
       DECLARE CUR_KITFRLOT02 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT KD.Lottable02, k.ExternKitKey
          FROM KIT K (NOLOCK)
          JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
          JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
          WHERE K.Kitkey = @c_KitKey
          AND KD.Type = 'F'
          AND KD.Lot IS NOT NULL
          AND KD.Lot <> '' 
          AND SI.ExtendedField07 = 'M'
          AND KD.Lottable02 IS NOT NULL
          AND KD.Lottable02 <> ''
          AND KD.Qty > 0
          GROUP BY KD.Lottable02, K.ExternKitKey
          ORDER BY KD.Lottable02

       OPEN CUR_KITFRLOT02  
       
       FETCH NEXT FROM CUR_KITFRLOT02 INTO @c_Lottable02, @c_ExternKitKey
       
       IF @@FETCH_STATUS <> 0
         SET @n_continue = 4
       
       SET @n_KitCnt = 0              
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  SET @n_KitCnt = @n_KitCnt + 1
       	  SET @c_NewKitkey = ''
       	  SET @n_KitLineNumber = 0
       	  SET @c_NewKitLineNumber = ''
        	
        	--Create new kit for each lottable02 of main sku
        	SET @b_success = 1	          	
          EXECUTE nspg_GetKey
                'kitting'
               ,10 
               ,@c_NewKitkey     OUTPUT 
               ,@b_success       OUTPUT 
               ,@n_err           OUTPUT 
               ,@c_errmsg        OUTPUT

          IF @b_success <> 1
          BEGIN
             SET @n_Continue = 3
          END 
          ELSE
          BEGIN
             INSERT INTO KIT (KitKey, Type, Facility, Storerkey, ToStorerkey, ExternKitkey, CustomerRefNo, ReasonCode, Remarks, USRDEF1, USRDEF2, USRDEF3)
             SELECT @c_NewKitkey, Type, Facility, Storerkey, ToStorerkey, ExternKitkey, CustomerRefNo, ReasonCode, Remarks, USRDEF1, USRDEF2, USRDEF3
             FROM KIT (NOLOCK)
             WHERE KitKey = @c_Kitkey             
 
             SET @n_err = @@ERROR
            
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Kit Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
             END             
          END
       	  
       	  --Split main sku to new kit       	  
          DECLARE CUR_MAINSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT KD.KITLineNumber, KD.Qty
             FROM KIT K (NOLOCK)
             JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
             JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
             WHERE K.Kitkey = @c_KitKey
             AND KD.Type = 'F'
             AND KD.Lot IS NOT NULL
             AND KD.Lot <> '' 
             AND SI.ExtendedField07 = 'M'
             AND KD.Lottable02 = @c_Lottable02
             AND KD.Qty > 0
             ORDER BY KD.KITLineNumber

          OPEN CUR_MAINSKU  
       
          FETCH NEXT FROM CUR_MAINSKU INTO @c_kitLineNumber, @n_Qty
          
          SET @n_MainQty = 0
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN
          	 SET @n_KitLineNumber = @n_KitLineNumber + 1	
          	 SET @c_NewKitLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_KitLineNumber AS NVARCHAR))),5)
          	
          	 SET @n_MainQty = @n_MainQty + @n_Qty
             
         	   INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, Lot, loc, id, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lottable01, Lottable02,
         	                          Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
             SELECT @c_NewKitkey, @c_NewKitLineNumber, Type, Storerkey, Sku, Lot, loc, id, Qty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lottable01, Lottable02,
                    Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
             FROM KITDETAIL (NOLOCK)
             WHERE Kitkey = @c_Kitkey
             AND KitLineNumber = @c_KitLineNumber          	                         
         	               
             SET @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert From Kitdetail Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
             END                    
          	 
             FETCH NEXT FROM CUR_MAINSKU INTO @c_kitLineNumber, @n_Qty
          END
          CLOSE CUR_MAINSKU
          DEALLOCATE CUR_MAINSKU
          
          --Split subsidiary sku to first kit only
          IF @n_KitCnt = 1
          BEGIN
       	     --Split subsidiary sku to new kit       	  
             DECLARE CUR_SUBSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                SELECT KD.KITLineNumber
                FROM KIT K (NOLOCK)
                JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
                JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
                WHERE K.Kitkey = @c_KitKey
                AND KD.Type = 'F'
                AND KD.Lot IS NOT NULL
                AND KD.Lot <> '' 
                AND SI.ExtendedField07 = 'S'
                AND KD.Qty > 0
                ORDER BY KD.KITLineNumber
             
             OPEN CUR_SUBSKU  
             
             FETCH NEXT FROM CUR_SUBSKU INTO @c_kitLineNumber
             
             WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
             BEGIN
            	 SET @n_KitLineNumber = @n_KitLineNumber + 1	
            	 SET @c_NewKitLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_KitLineNumber AS NVARCHAR))),5)
             
         	     INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, Lot, loc, id, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lottable01, Lottable02,
         	                            Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               SELECT @c_NewKitkey, @c_NewKitLineNumber, Type, Storerkey, Sku, Lot, loc, id, Qty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lottable01, Lottable02,
                      Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
               FROM KITDETAIL (NOLOCK)
               WHERE Kitkey = @c_Kitkey
               AND KitLineNumber = @c_KitLineNumber          	                         
         	                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert From Kitdetail Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
               END                    
             	 
                FETCH NEXT FROM CUR_SUBSKU INTO @c_kitLineNumber
             END
             CLOSE CUR_SUBSKU
             DEALLOCATE CUR_SUBSKU          	 
          END
          
          --Split final sku to new kit
       	  SET @n_KitLineNumber = @n_KitLineNumber + 1	
          SET @c_NewKitLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_KitLineNumber AS NVARCHAR))),5)
          SET @c_Lottable02 = ''
          
          SELECT TOP 1 @c_Lottable01 = KD.Lottable01,
                       @c_Lottable02 = KD.Lottable02, 
                       @c_Lottable03 = KD.Lottable03, 
                       @d_Lottable04 = KD.Lottable04,                       
                       @d_Lottable05 = KD.Lottable05,                       
                       @c_Lottable06 = KD.Lottable06,                       
                       @c_Lottable07 = KD.Lottable07,                       
                       @c_Lottable08 = KD.Lottable08,                       
                       @c_Lottable09 = KD.Lottable09,                       
                       @c_Lottable10 = KD.Lottable10,                       
                       @c_Lottable11 = KD.Lottable11,                       
                       @c_Lottable12 = KD.Lottable12,                       
                       @d_Lottable13 = KD.Lottable13,                       
                       @d_Lottable14 = KD.Lottable14,                       
                       @d_Lottable15 = KD.Lottable15                       
          FROM KIT K (NOLOCK)
          JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
          JOIN SKUINFO SI (NOLOCK) ON KD.Storerkey = SI.Storerkey AND KD.Sku = SI.Sku 
          WHERE K.Kitkey = @c_NewKitKey
          AND KD.Type = 'F'
          AND SI.ExtendedField07 = 'M'
          ORDER BY KD.Lottable05 DESC                    
          
         	INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, Lot, loc, id, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lottable01, Lottable02,
         	                       Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
          SELECT TOP 1 @c_NewKitkey, @c_NewKitLineNumber, Type, Storerkey, Sku, Lot, @c_FinalLoc, id, @n_MainQty, @n_MainQty, Packkey, UOM, ExternKitkey, ExternLineNo, @c_ExternKitKey, @c_Lottable02,
                 Lottable03, Lottable04, @d_Lottable05, Lottable06, @c_Lottable07, Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, Lottable12, Lottable13, Lottable14, Lottable15  --NJOW01
          FROM KITDETAIL (NOLOCK)
          WHERE Kitkey = @c_Kitkey
          AND Type = 'T'
         	            
          SET @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert To Kitdetail Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
          END                    
       	         	  
          FETCH NEXT FROM CUR_KITFRLOT02 INTO @c_Lottable02, @c_ExternKitKey
       END
       CLOSE CUR_KITFRLOT02
       DEALLOCATE CUR_KITFRLOT02           	
    END
    
    --Update Original Kitdetail
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	
       DECLARE CUR_ORGKIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT KD.KITLineNumber
          FROM KIT K (NOLOCK)
          JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
          WHERE K.Kitkey = @c_KitKey
          AND KD.Qty > 0
          ORDER BY KD.KITLineNumber
       
       OPEN CUR_ORGKIT  
       
       FETCH NEXT FROM CUR_ORGKIT INTO @c_kitLineNumber
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  UPDATE KITDETAIL WITH (ROWLOCK)
       	  SET ExpectedQty = ExpectedQty - Qty,
       	      Qty = 0,
       	      TrafficCop = NULL
       	  WHERE Kitkey = @c_KitKey
       	  AND KitLineNumber = @c_KitLineNumber

          SET @n_err = @@ERROR

          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Original Kitdetail Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
          END                    
       	  
          FETCH NEXT FROM CUR_ORGKIT INTO @c_kitLineNumber
       END    	    
       CLOSE CUR_ORGKIT
       DEALLOCATE CUR_ORGKIT	             
    END
    
    --Update Original Kit
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	
       UPDATE KIT WITH (ROWLOCK)
       SET Status = '5'
       WHERE Kitkey = @c_Kitkey
       
       SET @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Original Kit Failed. (ispRLKIT04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             	
       END                           
    END
              
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLKIT04"  
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
 END --sp end

GO