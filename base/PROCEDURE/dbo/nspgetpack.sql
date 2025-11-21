SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: nspgetpack                                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Putaway                                                     */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2010-01-06 1.1  ChewKP   SOS#157089 Get PackKey for Pre-Pack(ChewKP01)*/  
/* 2010-05-02 1.2  Shong    SOS#171385 Bug Fixing - RTRIM Issues        */ 
/* 2010-10-03 1.3  Shong    If Pre-Pack (Lottable03) = BLANK, then      */
/*                          Get from SKU (Shong01)                      */ 
/* 2011-12-16 1.4  ChewKP   Revise Select Statement (ChewKP02)          */ 
/* 2017-07-27 1.5  TLTING   SET Option                                  */
/************************************************************************/  
CREATE PROC [dbo].[nspGetPack]  
@c_storerkey   NVARCHAR(15)  
,              @c_sku         NVARCHAR(20)  
,              @c_lot         NVARCHAR(10)  
,              @c_loc         NVARCHAR(10)  
,              @c_id          NVARCHAR(18)  
,              @c_PackKey     NVARCHAR(10)          OUTPUT  
,              @b_success     INT               OUTPUT  
,              @n_err         INT               OUTPUT  
,              @c_errmsg      NVARCHAR(250)         OUTPUT  
AS  
BEGIN
    -- main proc  
    SET NOCOUNT ON   
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    DECLARE @b_hold        NVARCHAR(10)  
    DECLARE @n_continue    INT
           ,@n_cnt         INT  
    
    DECLARE @c_PrePackBOM  NVARCHAR(1)
           ,@c_BOMPallet   NVARCHAR(1)  
    
    SELECT @n_continue = 1
          ,@n_cnt = 0 
    -- SELECT @b_success = 1  
    IF ISNULL(RTRIM(@c_PackKey) ,'')=''
    BEGIN
        -- LTrim(RTrim(@c_PackKey)  
        SELECT @b_hold = OnReceiptCopyPackKey
        FROM   SKU(NOLOCK)
        WHERE  storerkey = @c_storerkey
        AND    sku = @c_sku  
        
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            -- SELECT @b_success=0  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 86001
            
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Select Failed On Sku. (nspGetPack)"+" (SQLSvr MESSAGE="+
                   LTRIM(RTRIM(@c_errmsg))+")"
        END  
        
        SELECT @c_PrePackBOM = SValue
        FROM   STORERCONFIG(NOLOCK)
        WHERE  CONFIGKEY = 'PREPACKBYBOM'
        AND    STORERKEY = @c_storerkey
        
        SELECT @c_BOMPallet = SValue
        FROM   STORERCONFIG(NOLOCK)
        WHERE  CONFIGKEY = 'BOMPallet'
        AND    STORERKEY = @c_storerkey  
        
        
        IF @n_continue=1 OR @n_continue=2
        BEGIN
            IF LTRIM(RTRIM(@b_hold))='1'
            BEGIN
                IF ISNULL(RTRIM(@c_lot) ,'')<>''
                BEGIN
                    IF @c_PrePackBOM='1' AND @c_BOMPallet='1' -- ChewKP01
                    BEGIN
                        SELECT DISTINCT @c_PackKey = U.PackKey
                        FROM   LOTxLOCxID LO(NOLOCK)
                        INNER JOIN LOTATTRIBUTE LA(NOLOCK) ON  LA.LOT = LO.LOT
                        INNER JOIN UPC U(NOLOCK) ON U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
                        WHERE  LO.LOT = @c_Lot
                        AND    LO.STorerkey = @c_storerkey
                    END
                    ELSE
                    BEGIN
                        SELECT @c_PackKey = Lottable01
                        FROM   LOTATTRIBUTE(NOLOCK)
                        WHERE  Lot = @c_lot
                        
                        SELECT @n_err = @@ERROR
                              ,@n_cnt = @@ROWCOUNT
                    END  
                    IF @n_err<>0
                    BEGIN
                        -- SELECT @b_success=0  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                              ,@n_err = 86002
                        
                        SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                               ": Select Failed On LOTATTRIBUTE. (nspGetPack)"+
                               " (SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+")"
                    END
                END
                ELSE
                BEGIN
                    IF ISNULL(RTRIM(@c_id) ,'')<>''
                    BEGIN
                        IF @c_PrePackBOM='1' AND @c_BOMPallet='1' -- ChewKP01
                        BEGIN
                            SELECT TOP 1 @c_PackKey = U.PackKey
                            FROM   LOTxLOCxID LO(NOLOCK)
                                   INNER JOIN LOTATTRIBUTE LA(NOLOCK)
                                        ON  LA.LOT = LO.LOT
                                   INNER JOIN UPC U(NOLOCK)
                                        ON  U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
                            WHERE  LO.ID = @c_id
                            AND    LO.STorerkey = @c_storerkey
       
                        END
                        ELSE
                        BEGIN
                            SELECT @c_PackKey = Lottable01
                            FROM   LOTxLOCxID(NOLOCK)
                                  ,LOTATTRIBUTE(NOLOCK)
                            WHERE  LOTxLOCxID.Id = @c_id
                            AND    Qty>0 -- JN: Added criteria
                            AND    LOTATTRIBUTE.Lot = LOTxLOCxID.Lot
                            GROUP BY 
                                   Lottable01
                        END  
                        SELECT @n_err = @@ERROR
                              ,@n_cnt = @@ROWCOUNT
                    END
                    ELSE
                    BEGIN
                        IF @c_PrePackBOM='1' AND @c_BOMPallet='1' -- ChewKP01
                        BEGIN
                            SELECT DISTINCT @c_PackKey = U.PackKey
                            FROM   LOTxLOCxID LO(NOLOCK)
                                   INNER JOIN LOTATTRIBUTE LA(NOLOCK)
                                        ON  LA.LOT = LO.LOT
                                   INNER JOIN UPC U(NOLOCK)
                                        ON  U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
                            WHERE  LO.SKU = @c_sku
                            AND    LO.Storerkey = @c_storerkey
                            AND    LO.LOC = @c_Loc
                        END
                        ELSE
                        BEGIN
                            SELECT @c_PackKey = Lottable01
                            FROM   LOTxLOCxID(NOLOCK)
                                  ,LOTATTRIBUTE(NOLOCK)
                            WHERE  LOTxLOCxID.StorerKey = @c_storerkey
                            AND    LOTxLOCxID.Sku = @c_sku
                            AND    LOTxLOCxID.Loc = @c_loc
                            AND    Qty>0
                            AND    LOTATTRIBUTE.Lot = LOTxLOCxID.Lot
                            GROUP BY
                                   Lottable01
                        END  
                        SELECT @n_err = @@ERROR
                              ,@n_cnt = @@ROWCOUNT
                    END  
                    IF @n_err<>0
                    BEGIN
                        -- SELECT @b_success=0  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                              ,@n_err = 86003
                        
                        SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                               ": Select PackKey Failed On LOTATTRIBUTE. (nspGetPack)" 
                              +" ( "+" SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg)) 
                              +" ) "
                    END
                    ELSE 
                    IF @n_cnt>1
                    BEGIN
                        -- SELECT @b_success=0  
                        SELECT @c_PackKey = '' -- Added by JN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                              ,@n_err = 86004
                        
                        SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                               ": Multiple Lots on id. (nspGetPack)"+" ( "+
                               " SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+" ) "
                    END
                END -- LTrim(RTrim(@c_lot)) IS NULL
            END-- @b_hold = '1'
            ELSE
            BEGIN
                IF (@n_continue=1 OR @n_continue=2)
                BEGIN
                    /** For Pre-Pack SKU get PackKey from UPC table ChewKP 11/01/2010 **/  
                    IF @c_PrePackBOM='1'
                    AND @c_BOMPallet='1' -- ChewKP01
                    BEGIN
                        SELECT DISTINCT @c_PackKey = U.PackKey
                        FROM   LOTxLOCxID LO(NOLOCK)
                               INNER JOIN LOTATTRIBUTE LA(NOLOCK)
                                    ON  LA.LOT = LO.LOT
                               INNER JOIN UPC U(NOLOCK)
                                    ON  U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
                        WHERE  LO.SKU = @c_sku
                        AND    LO.Storerkey = @c_storerkey
                    END
                    ELSE
                    BEGIN
                        SELECT @c_PackKey = PackKey
                        FROM   SKU(NOLOCK)
                        WHERE  StorerKey = @c_storerkey
                        AND    Sku = @c_sku
                    END  
                    
                    SELECT @n_err = @@ERROR
                          ,@n_cnt = @@ROWCOUNT
                    
                    IF @n_err<>0
                    BEGIN
                        -- SELECT @b_success=0  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                              ,@n_err = 86007
                        
                        SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                               ": Select Failed On SKU. (nspGetPack)"+
                               " ( SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+
                               " ) "
                    END
                END
            END -- @b_hold <> 1
        END-- @n_continue stuff
    END -- LTrim(RTrim(@c_PackKey)) IS NULL  
    
    IF ((@n_continue=1 OR @n_continue=2)
       AND (ISNULL(RTRIM(@c_id) ,'')<>'')
       AND (ISNULL(RTRIM(@c_PackKey) ,'')='')
       OR  ISNULL(RTRIM(@c_PackKey) ,'')=''
       )
    BEGIN
        DECLARE @n_dummy INT  
        
--       (ChewKP02)
--        SELECT @n_dummy = COUNT(*)
--        FROM   LOTxLOCxID(NOLOCK)
--        WHERE  ID = @c_id
--        AND    Qty>0
--        GROUP BY StorerKey, Sku
        
        SELECT @n_dummy = COUNT(DISTINCT SKU) 
        FROM   LOTxLOCxID(NOLOCK)
        WHERE  ID = @c_id
        AND    Qty>0
        GROUP BY StorerKey, Sku

        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 86005
            
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Select Failed On LOTxLOCxID. (nspGetPack)" 
                  +" (SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+")"
        END
        ELSE 
        IF @n_cnt=1
        BEGIN
            SELECT @c_PackKey = ID.PackKey
            FROM   ID(NOLOCK)
            WHERE  ID.Id = @c_id 
            -- GROUP BY ID  -- JN: Commented Group By clause  
            
            SELECT @n_err = @@ERROR
                  ,@n_cnt = @@ROWCOUNT
            
            IF @n_err<>0
            BEGIN
                -- SELECT @b_success=0  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                      ,@n_err = 86006
                
                SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                       ": Select Failed On ID. (nspGetPack)" 
                      +" (SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+")"
            END
        END-- @n_cnt = 1
        ELSE 
        IF @n_cnt>1
        BEGIN
            /** For Pre-Pack SKU Do not do this validation ChewKP01 11/01/2010 **/   
            
            IF @c_PrePackBOM='1' AND @c_BOMPallet='1' -- ChewKP01
            BEGIN
                SELECT DISTINCT @c_PackKey = U.PackKey
                FROM   LOTxLOCxID LO(NOLOCK)
                       INNER JOIN LOTATTRIBUTE LA(NOLOCK)
                            ON  LA.LOT = LO.LOT
                       INNER JOIN UPC U(NOLOCK)
                            ON  U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
                WHERE  LO.ID = @c_ID
                AND    LO.Storerkey = @c_storerkey
            END
            ELSE
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                      ,@n_err = 86050
                
                SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                       ": > 1 Sku in PLT . (nspGetPack)" 
                      +" (SQLSvr MESSAGE="+LTRIM(RTRIM(@c_errmsg))+")"
            END
        END
    END -- LTrim(RTrim(@c_id)) IS NOT NULL  
    
    /* Added By Vicky 09 Apr 2003- CDC Migration */  
    IF ((@n_continue=1 OR @n_continue=2) AND ISNULL(RTRIM(@c_PackKey) ,'')='')
    BEGIN
        IF @c_PrePackBOM='1' AND @c_BOMPallet='1' -- ChewKP01
        BEGIN
            SELECT TOP 1 
                   @c_PackKey = U.PackKey
            FROM   LOTxLOCxID LO(NOLOCK)
                   INNER JOIN LOTATTRIBUTE LA(NOLOCK)
                        ON  LA.LOT = LO.LOT
                   INNER JOIN UPC U(NOLOCK)
                        ON  U.StorerKey = LA.StorerKey AND LA.Lottable03 = U.SKU
            WHERE  LO.SKU = @c_sku
            AND    LO.Storerkey = @c_storerkey
            
            IF ISNULL(RTRIM(@c_PackKey),'')=''
            BEGIN
               SELECT @c_PackKey = PackKey
               FROM   SKU (NOLOCK)
               WHERE  StorerKey = @c_storerkey
               AND    Sku = @c_sku
            END  
        END
        ELSE
        BEGIN
            SELECT @c_PackKey = PackKey
            FROM   SKU(NOLOCK)
            WHERE  StorerKey = @c_storerkey
            AND    Sku = @c_sku
        END  
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            --               SELECT @b_success=0  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 86007
            
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Select Failed On SKU. (nspGetPack)"+" ( SQLSvr MESSAGE="+
                   LTRIM(RTRIM(@c_errmsg))+" ) "
        END
    END 
    /* CDC Migration End */  
    
    IF @n_continue=1
    OR @n_continue=2
    BEGIN
        IF ISNULL(RTRIM(@c_PackKey) ,'')<>''
        BEGIN
            IF NOT EXISTS (
                   SELECT 1
                   FROM   PACK(NOLOCK)
                   WHERE  PackKey = @c_PackKey
               )
            BEGIN
                -- SELECT @b_success=0  
                SELECT @n_continue = 3  
                SELECT @n_err = 86008  
                SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                       ": PackKey Does Not Exist. (nspGetPack)"
            END
        END
        ELSE
        BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 86009  
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Cannot Determine PackKey. (nspGetPack)"
        END
    END  
    
    IF @n_continue=3
    BEGIN
        SELECT @b_success = 0  
        EXEC nsp_logerror @n_err
            ,@c_errmsg
            ,"nspGetPack"
        
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    END
    ELSE
        SELECT @b_success = 1
END -- main proc

GO