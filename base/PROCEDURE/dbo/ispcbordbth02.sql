SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispCBORDBTH02                                       */  
/* Creation Date: 09-DEC-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-15652-HK - Lululemon Relocation Project-Combine Order CR */  
/*                                                                       */  
/* Called By: isp_CombineOrderByMultiBatchSP_Wrapper                     */  
/*                                                                       */  
/* GitLab Version: 1.1                                                   */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 2020-12-09  Wan      1.0   Creation                                   */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[ispCBORDBTH02]  
      @c_OrderList          NVARCHAR(MAX)  -- seperator ','
   ,  @b_Success            INT           = 1   OUTPUT    
   ,  @n_Err                INT           = 0   OUTPUT
   ,  @c_Errmsg             NVARCHAR(255) = ''  OUTPUT
   ,  @c_FromOrderkeyList   NVARCHAR(MAX) = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_SPCode          NVARCHAR(50)   = '' 
         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_authority       NVARCHAR(10)   = ''
         , @b_debug           INT = 0        
                                             
         , @d_Trace_StartTime DATETIME       
         , @d_Trace_EndTime   DATETIME       
         , @c_UserName        NVARCHAR(100)  = ''

         , @n_Continue        INT = 1
         , @n_starttcnt       INT = @@TRANCOUNT

         , @c_MinBuyerPO      NVARCHAR(20)   = ''
         , @c_Consigneekey    NVARCHAR(15)   = ''
         , @c_UserDefine05    NVARCHAR(20)   = ''
         , @c_SectionKey      NVARCHAR(10)   = ''
         , @c_FromOrderkey    NVARCHAR(10)   = ''
         , @c_ToOrderkey      NVARCHAR(10)   = ''
         , @c_Facility        NVARCHAR(10)   = ''
         , @c_StorerKey       NVARCHAR(15)   = ''
         , @c_OrderkeyList    NVARCHAR(MAX)  = ''
         
         , @c_LULUECOM        NVARCHAR(255)  = ''
         
         , @CUR_LOOP          CURSOR
         , @CUR_FromOrderkey  CURSOR

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @c_FromOrderkeyList = ''

   SET @d_Trace_StartTime = GETDATE()


   --Check if Buyerpo is numerical number, if yes, need to sort by CAST(BuyerPO AS INT), if not below situation will happpen:
   --Given BuyerPO 123, 1000
   --MIN(CAST(BuyerPO AS INT)) will be 123
   --MIN(BuyerPO) will be 1000 -- which is wrong

   IF OBJECT_ID('tempdb..#TEMP_ORD') IS NOT NULL
   BEGIN
      DROP TABLE #TEMP_ORD
   END
   
   CREATE TABLE #TEMP_ORD (
         Orderkey       NVARCHAR(10)   PRIMARY KEY
      ,  [Type]         NVARCHAR(10) 
      ,  OrderType      NVARCHAR(10)   
      ,  ConsigneeKey   NVARCHAR(15)
      ,  UserDefine05   NVARCHAR(20)
      ,  SectionKey     NVARCHAR(10)
      ,  BuyerPO        NVARCHAR(10)
   ) 
   
   IF OBJECT_ID('tempdb..#TEMP_COMBINEGRP') IS NOT NULL
   BEGIN
      DROP TABLE #TEMP_COMBINEGRP
   END
   
   CREATE TABLE #TEMP_COMBINEGRP (
         RowRef         INT   IDENTITY(1,1) PRIMARY KEY
      ,  OrderType      NVARCHAR(10)   
      ,  ConsigneeKey   NVARCHAR(15)
      ,  UserDefine05   NVARCHAR(20)
      ,  SectionKey     NVARCHAR(10)
      ,  MinBuyerPO     NVARCHAR(10)
      ,  ToOrderkey     NVARCHAR(10)
      ,  OrderKeyList   NVARCHAR(MAX)
   )
     
   INSERT INTO #TEMP_ORD (Orderkey, TYPE, OrderType, Consigneekey, UserDefine05, Sectionkey, BuyerPO)
   SELECT DISTINCT 
        o.Orderkey
      , o.[Type]
      , OrderType    = CASE WHEN o.[Type] = 'LULUSTOR' THEN o.[Type] ELSE '' END
      , ConsigneeKey = ISNULL(o.ConsigneeKey,'')
      , UserDefine05 = ISNULL(o.UserDefine05,'')
      , SectionKey   = CASE WHEN SUBSTRING(ISNULL(o.UserDefine05,''),5,1) = 'A' THEN ISNULL(o.SectionKey,'') ELSE '' END
      , BuyerPO      = RIGHT('0000000000' + ISNULL(o.BuyerPO,''),10)    
   FROM STRING_SPLIT (@c_OrderList,',') SS
   JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = SS.VALUE
   ORDER BY o.[Type]
      , CASE WHEN o.[Type] = 'LULUSTOR' THEN o.[Type] ELSE '' END
      , ISNULL(o.ConsigneeKey,'')
      , ISNULL(o.UserDefine05,'')
      , CASE WHEN SUBSTRING(ISNULL(o.UserDefine05,''),5,1) = 'A' THEN ISNULL(o.SectionKey,'') ELSE '' END
      , RIGHT('0000000000' + ISNULL(o.BuyerPO,''),10)  
   
   
      
   SET @c_LULUECOM = ISNULL(STUFF(( SELECT TOP 15 ',' + RTRIM(o.Orderkey) 
                               FROM #TEMP_ORD O 
                               WHERE o.[Type] = 'LULUECOM'
                               ORDER BY o.Orderkey 
                               FOR XML PATH('')),1,1,'' ),'')   
   
   IF @c_LULUECOM <> ''
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err = 62210
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)  
                        + ': LuluECOM Order: ' + @c_LULUECOM 
                        + '... found. (ispCBORDBTH02)'  
      GOTO QUIT_SP
   END
   

      
   INSERT INTO #TEMP_COMBINEGRP
      ( OrderType, ConsigneeKey, UserDefine05, SectionKey, MinBuyerPO, ToOrderkey, OrderKeyList ) 
   SELECT to1.OrderType
      , to1.ConsigneeKey
      , to1.UserDefine05
      , to1.SectionKey
      , BuyerPO = MIN(to1.BuyerPO)
      , ToOrderkey  = ''
      , OrderKeyList= '' 
   FROM #TEMP_ORD AS to1 
   GROUP BY 
        to1.OrderType
      , to1.ConsigneeKey
      , to1.UserDefine05
      , to1.SectionKey
   ORDER BY
        to1.OrderType
      , to1.ConsigneeKey
      , to1.UserDefine05
      , to1.SectionKey 
      
   --   SELECT *  FROM #TEMP_ORD
                        
   --       SELECT to1.OrderType, To1.ConsigneeKey, To1.UserDefine05, To1.Sectionkey,To1.MinBuyerPO, To1.ToOrderkey, To1.OrderkeyList
   --FROM #TEMP_COMBINEGRP AS To1
      
   UPDATE #TEMP_COMBINEGRP
      SET ToOrderkey= ( SELECT TOP 1 to1.Orderkey
                        FROM #TEMP_ORD AS to1 
                        WHERE to1.Ordertype = T.OrderType
                        AND to1.ConsigneeKey= T.ConsigneeKey
                        AND to1.UserDefine05= T.UserDefine05
                        AND to1.SectionKey  = T.SectionKey
                        AND to1.BuyerPO     = T.MinBuyerPO
                        ORDER BY to1.Orderkey
                        )
      ,OrderKeyList = ISNULL(STUFF(( SELECT ',' + RTRIM(to2.Orderkey)
                               FROM #TEMP_ORD AS to2  
                               WHERE to2.Ordertype = T.OrderType
                               AND to2.ConsigneeKey= T.ConsigneeKey
                               AND to2.UserDefine05= T.UserDefine05
                               AND to2.SectionKey  = T.SectionKey
                               ORDER BY to2.Orderkey
                               FOR XML PATH('')),1,1,'' ),'') 
   FROM #TEMP_COMBINEGRP T                              
 
   SET @CUR_LOOP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT To1.MinBuyerPO, To1.ConsigneeKey, To1.UserDefine05, To1.Sectionkey, To1.ToOrderkey, To1.OrderkeyList
   FROM #TEMP_COMBINEGRP AS To1
   ORDER BY RowRef

   OPEN @CUR_LOOP

   FETCH NEXT FROM @CUR_LOOP INTO @c_MinBuyerPO, @c_Consigneekey, @c_UserDefine05, @c_Sectionkey, @c_ToOrderkey, @c_OrderkeyList

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC isp_PreCombineOrder_Wrapper
         @c_ToOrderkey = @c_ToOrderkey
       , @c_OrderList  = @c_OrderkeyList
       , @b_Success    = @b_Success OUTPUT
       , @n_Err        = @n_Err     OUTPUT
       , @c_ErrMsg     = @c_ErrMsg  OUTPUT

      IF @b_Success = 0 AND @c_ErrMsg <> ''
      BEGIN
         SET @n_Continue = 3   
         GOTO QUIT_SP
      END
      
      SELECT @c_facility  = Facility
           , @c_StorerKey = Storerkey
      FROM ORDERS (NOLOCK)
      WHERE OrderKey = @c_ToOrderkey
      
      SET @c_SPCode = ''
      EXEC nspGetRight
            @c_Facility   = @c_Facility  
         ,  @c_StorerKey  = @c_StorerKey 
         ,  @c_sku        = ''       
         ,  @c_ConfigKey  = 'CombineOrderSP' 
         ,  @b_Success    = @b_Success    OUTPUT
         ,  @c_authority  = @c_SPCode     OUTPUT 
         ,  @n_err        = @n_err        OUTPUT
         ,  @c_errmsg     = @c_errmsg     OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 62220   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - CombineOrderSP. (ispCBORDBTH02)'   
         GOTO QUIT_SP  
      END

      
      IF @c_SPCode IN ('','0', '1') OR NOT EXISTS (SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = RTRIM(@c_SPCode) AND type = 'P')
      BEGIN
         SET @n_Continue = 3  
         SET @n_Err = 62230
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)  
                          + ': Storerconfig CombineOrderSP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                          + '). (ispCBORDBTH02)'  
         GOTO QUIT_SP
      END

      SET @CUR_FromOrderkey = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT SS.[Value] 
      FROM STRING_SPLIT (@c_OrderkeyList, ',') SS
      ORDER BY SS.[Value]

      OPEN @CUR_FromOrderkey

      FETCH NEXT FROM @CUR_FromOrderkey INTO @c_FromOrderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_FromOrderkey <> @c_ToOrderkey
         BEGIN
            SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_FromOrderkey, @c_ToOrderkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT'

            EXEC sp_executesql @c_SQL 
               ,  N'@c_FromOrderkey NVARCHAR(10), @c_ToOrderkey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
               ,  @c_FromOrderkey
               ,  @c_ToOrderkey
               ,  @b_Success OUTPUT   
               ,  @n_Err OUTPUT
               ,  @c_ErrMsg OUTPUT

            IF @b_Success = 0 AND @c_ErrMsg <> ''
            BEGIN
               SET @n_Continue = 3   
               GOTO QUIT_SP
            END

            IF @c_FromOrderkeyList = ''
            BEGIN
               SET @c_FromOrderkeyList = @c_FromOrderkey
            END
            ELSE
            BEGIN
               SET @c_FromOrderkeyList = @c_FromOrderkeyList + ',' + @c_FromOrderkey
            END
         END

         FETCH NEXT FROM @CUR_FromOrderkey INTO @c_FromOrderkey
      END

      CLOSE @CUR_FromOrderkey
      DEALLOCATE @CUR_FromOrderkey   

      FETCH NEXT FROM @CUR_LOOP INTO @c_MinBuyerPO, @c_Consigneekey, @c_UserDefine05, @c_Sectionkey, @c_ToOrderkey, @c_OrderkeyList
   END
   CLOSE @CUR_LOOP
   DEALLOCATE @CUR_LOOP 
   
QUIT_SP:
   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

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
     EXECUTE nsp_logerror @n_err, @c_errmsg, "ispCBORDBTH02"  
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