SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_NIKE_OrderdetailUpdate                         */
/* Creation Date: 22-Nov-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2911 Nike CRW VAS Logic - Orderdetail Update            */       
/*                                                                      */
/*                                                                      */
/* Called By: SQL Job                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 20-Dec-2017  NJOW01   1.0  Fix - convert susr5 to integer            */
/* 23-Jul-2018  AikLiang 1.1  Fix Endtime only capture until 59min      */
/* 12-Nov-2018  NJOW02   1.1  WMS-6977 Support set storer by parameter  */
/*                            and add additional logic                  */
/* 04-Jun-2019  WLCHOOI  1.3  WMS-9256 - Add new VAS Line update logic  */ 
/*                            (WL01)                                    */
/* 10-Jul-2019  WLCHOOI  1.4  Fix - The job will fail when scheduled to */
/*                            run at 12:00 am (WL02)                    */
/************************************************************************/
CREATE PROC [dbo].[isp_NIKE_OrderdetailUpdate]  
    @c_Storerkey  NVARCHAR(15) 
AS   
BEGIN      
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT,
            @b_Success     INT, 
            @n_Err         INT,
            @c_ErrMsg      NVARCHAR(250)      
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''    
                                                                                  
   DECLARE @c_ConsigneeKey    NVARCHAR(15) = '', 
           @c_SKU             NVARCHAR(20) = '', 
           @c_Type            NVARCHAR(10) = '',
           @c_CODE2           NVARCHAR(30) = '',
           @c_SUSR1           NVARCHAR(18) = '', 
           @c_SUSR2           NVARCHAR(18) = '',
           @c_SUSR3           NVARCHAR(18) = '',
           @c_BUSR7           NVARCHAR(30) = '',
           @c_OrderKey        NVARCHAR(10) = '',
           @c_OrderLineNumber NVARCHAR(5)  = '',
           @c_VAS_Instruction NVARCHAR(4000) = '',
           @b_NKSHANGER       BIT = 0, 
           @c_BUSR3           NVARCHAR(30) = '',  --NJOW02
           @c_BUSR4           NVARCHAR(200) = '', 
           @c_SUSR5           NVARCHAR(18) = '',
           @n_SUSR5           INT = 0, --NJOW01
           @dt_GetDate        DATETIME --WL02
   
   DECLARE @d_StartTime       DATETIME, 
           @d_EndTime         DATETIME
                   
   DECLARE @t_VAS_Line TABLE ( SeqNo INT IDENTITY(1,2), 
                               Notes NVARCHAR(4000) )
   --WL02 START
   SET @dt_GetDate = GETDATE()

   IF( DATEPART(HOUR, CONVERT(VARCHAR(100), @dt_GetDate, 121)) = 0  ) --1200 AM
   BEGIN
      SET @d_StartTime = CONVERT(VARCHAR(12), DATEADD(DAY, -1, @dt_GetDate), 112) + ' ' + 
                         RIGHT('0' + CONVERT(VARCHAR(2), DATEPART(HOUR,(DATEADD(HOUR, -1, @dt_GetDate))) ), 2) + ':00'
   
      SET @d_EndTime = CONVERT(VARCHAR(12), DATEADD(DAY, -1, @dt_GetDate), 112) + ' ' + 
                         RIGHT('0' + CONVERT(VARCHAR(2), DATEPART(HOUR,(DATEADD(HOUR, -1, @dt_GetDate))) ), 2) + ':59:59.999' 
   END
   ELSE 
   BEGIN --WL02 END
      --SET @c_StorerKey = 'NIKECN' 
      SET @d_StartTime = CONVERT(VARCHAR(12), GETDATE(), 112) + ' ' + 
                         RIGHT('0' + CONVERT(VARCHAR(2), (DATEPART(hour, GETDATE()) -1)), 2) + ':00'
   
      SET @d_EndTime = CONVERT(VARCHAR(12), GETDATE(), 112) + ' ' + 
                         RIGHT('0' + CONVERT(VARCHAR(2), (DATEPART(hour, GETDATE()) -1)), 2) + ':59:59.999' 
                       --RIGHT('0' + CONVERT(VARCHAR(2), (DATEPART(hour, GETDATE()) -1)), 2) + ':59'
   END
          
   DECLARE CUR_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT OH.ConsigneeKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, ISNULL(SKU.SUSR1, '') AS [SUSR1], ISNULL(SKU.SUSR3,'') AS [SUSR3], 
          ISNULL(SKU.BUSR7, '') BUSR7, ISNULL(SKU.BUSR4, '') BUSR4, ISNULL(SKU.SUSR2, '') AS [SUSR2], ISNULL(SKU.SUSR5,'') AS [SUSR5],
          ISNULL(SKU.BUSR3, '') BUSR3  --NJOW02
   FROM ORDERS AS OH WITH(NOLOCK)
   JOIN ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = OH.OrderKey 
   JOIN SKU AS SKU WITH (NOLOCK) ON SKU.Sku = OD.Sku AND SKU.StorerKey = OD.StorerKey   
   WHERE OH.StorerKey = @c_StorerKey
   AND   OH.ConsigneeKey IS NOT NULL 
   AND   OH.ConsigneeKey <> ''  
   AND   OH.AddDate BETWEEN @d_StartTime AND @d_EndTime
   AND   EXISTS (SELECT 1 
                 FROM CODELKUP AS c WITH(NOLOCK) 
                 WHERE c.LISTNAME IN ('NKSHANGER', 'NKSTAG','NKSOTW','NKRFIDTAG')  --NJOW02   --WL01
                 AND c.code2 = OH.ConsigneeKey
                 AND c.Storerkey = OH.Storerkey --NJOW02
                )               
   ORDER BY OD.OrderKey ASC              
   
   OPEN CUR_ORDERDETAIL
   FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_ConsigneeKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @c_SUSR1, @c_SUSR3, @c_BUSR7, @c_BUSR4, @c_SUSR2, @c_SUSR5, @c_BUSR3
   
   BEGIN TRAN
   
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN
      SET @c_VAS_Instruction = ''
      
      --NJOW01
      IF ISNUMERIC(@c_Susr5) = 1
         SET @n_Susr5 = CAST(@c_Susr5 AS INT)
      ELSE
         SET @n_Susr5 = 0
      
      -- Initialise Table 
      DELETE @t_VAS_Line
    	  
      IF @c_SUSR1 <> ''	          
      BEGIN   	
      	 INSERT INTO @t_VAS_Line (Notes) 
      	 SELECT ISNULL(c.Notes2, '') 
   	     FROM CODELKUP AS c WITH(NOLOCK) 
   	     WHERE c.LISTNAME = 'NKSHANGER'
   	     AND   c.Code = @c_SUSR1
   	     AND   c.code2 = @c_ConsigneeKey
   	     AND   c.Storerkey = @c_Storerkey --NJOW02
         
         IF @@ROWCOUNT > 0 	         	
   	       SET @b_NKSHANGER = 1 
   	     ELSE 
   	       SET @b_NKSHANGER = 0 
      END
      
      IF @b_NKSHANGER IN(0,1) 
      BEGIN
      	IF @c_BUSR7 IN ('10','20')
      	BEGIN
      	   INSERT INTO @t_VAS_Line (Notes) 
      	   SELECT ISNULL(c.Notes2, '')  
   	       FROM CODELKUP AS c WITH(NOLOCK) 
   	       WHERE c.LISTNAME = 'NKSTAG'
   	       AND   c.Short = @c_BUSR7 
   	       AND   c.Long  = @c_BUSR4 
   	       AND   CAST(ISNULL(c.UDF01,'0') AS INT) <= @n_SUSR5  --NJOW01 
   	       AND   c.code2 = @c_ConsigneeKey      		
   	       AND   (ISNUMERIC(c.UDF01) = 1 OR ISNULL(c.UDF01,'') = '') --NJOW01
             AND   c.Storerkey = @c_Storerkey --NJOW02
             UNION ALL                        --WL01 START
             SELECT ISNULL(c.Notes2, '')  
             FROM CODELKUP AS c WITH(NOLOCK) 
             WHERE c.LISTNAME = 'NKRFIDTAG'
             AND   c.code2 = @c_ConsigneeKey
             AND   c.Storerkey = @c_Storerkey --WL01 END
      	END
      	ELSE IF @c_BUSR7 IN ('30')
      	BEGIN
      	   INSERT INTO @t_VAS_Line (Notes) 
      	   SELECT ISNULL(c.Notes2, '')  
   	       FROM CODELKUP AS c WITH(NOLOCK) 
   	       WHERE c.LISTNAME = 'NKSTAG'
   	       AND   c.Short = @c_BUSR7 
   	       AND   c.Long  = @c_SUSR2 
   	       AND   CAST(ISNULL(c.UDF01,'0') AS INT) <= @n_SUSR5  --NJOW01
   	       AND   c.code2 = @c_ConsigneeKey    		
   	       AND   (ISNUMERIC(c.UDF01) = 1 OR ISNULL(c.UDF01,'') = '') --NJOW01
    	     AND   c.Storerkey = @c_Storerkey --NJOW02
      	END 	
      END	
        
      --NJOW02 	   
      IF ISNULL(@c_BUSR3,'') <> ''
      BEGIN
         INSERT INTO @t_VAS_Line (Notes) 
         SELECT ISNULL(c.Notes2, '')  
   	     FROM CODELKUP AS c WITH(NOLOCK) 
   	     WHERE c.LISTNAME = 'NKSOTW'
   	     AND   c.Code = @c_BUSR3 
   	     AND   c.code2 = @c_ConsigneeKey    		
    	   AND   c.Storerkey = @c_Storerkey 
      END
               
      IF NOT EXISTS(SELECT 1 FROM OrderDetailRef AS odr WITH(NOLOCK)
      		      WHERE odr.Orderkey = @c_OrderKey 
      		      AND   odr.OrderLineNumber = @c_OrderLineNumber)
         AND EXISTS(SELECT 1 FROM @t_VAS_Line)
      BEGIN
      	 DECLARE CUR_VAS_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	 SELECT Notes 
      	 FROM @t_VAS_Line
      	 ORDER BY SeqNo 
      	 
      	 OPEN CUR_VAS_LINES
      	 
      	 FETCH FROM CUR_VAS_LINES INTO @c_VAS_Instruction
      	 
      	 WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      	 BEGIN
      	    INSERT INTO OrderDetailRef (Orderkey, OrderLineNumber, StorerKey, ParentSKU,
      	                Note1, RefType)
      	    VALUES (@c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_SKU, @c_VAS_Instruction, 'PI')

            SET @n_Err = @@ERROR        
                                        
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 13500
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Insert OrderDetailRef Failed. (isp_NIKE_OrderdetailUpdate)'
            END
      	    
      	 	  FETCH FROM CUR_VAS_LINES INTO @c_VAS_Instruction
      	 END
      	 
      	 CLOSE CUR_VAS_LINES
      	 DEALLOCATE CUR_VAS_LINES   	
      END          
      	
     	FETCH NEXT FROM CUR_ORDERDETAIL INTO  @c_ConsigneeKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @c_SUSR1, @c_SUSR3, @c_BUSR7, @c_BUSR4, @c_SUSR2, @c_SUSR5, @c_BUSR3
   END
   CLOSE CUR_ORDERDETAIL
   DEALLOCATE CUR_ORDERDETAIL   
  
EXIT_SP:  
      
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_Success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_NIKE_OrderdetailUpdate'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR          
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END           
END -- Procedure    

GO