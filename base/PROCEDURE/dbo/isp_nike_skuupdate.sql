SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_NIKE_SkuUpdate                                 */
/* Creation Date: 22-Nov-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2911 Nike CRW VAS Logic - Sku Update                    */       
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
/* 04/12/2017   NJOW01   1.0  Fix update transmitlog3.transmitflag to 9 */
/* 21/11/2018   NJOW02   1.1  WMS-6977 Support set storer by parameter  */ 
/************************************************************************/
CREATE PROC [dbo].[isp_NIKE_SkuUpdate]  
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
                                                                                  
   -- Prerequisite:
   -- Turn on StorerConfig ADDSKULOG and UPDSKULOG
   -- Insert Column Name Required to Update to Codelkup, ListName = TRTL3SKU
   
   DECLARE @c_ConsigneeKey NVARCHAR(15) = '', 
           @c_SKU    NVARCHAR(20) = '', 
           @c_Type   NVARCHAR(10) = '',
           @c_CODE2  NVARCHAR(30) = '',
           @c_SUSR1  NVARCHAR(18) = '', 
           @c_SUSR2  NVARCHAR(18) = '',
           @c_SUSR3  NVARCHAR(18) = '',
           @c_BUSR4  NVARCHAR(30) = '',
           @c_BUSR7  NVARCHAR(30) = ''
      
   DECLARE @c_TransmitLogKey nvarchar(10)
         , @c_tablename nvarchar(30)
         , @c_key1 nvarchar(10)
         , @c_key3 nvarchar(20)
         , @c_transmitflag nvarchar(5)
   
   DECLARE CUR_TRANSMITLOG3_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TransmitLogKey, Key3
   FROM TRANSMITLOG3 WITH (NOLOCK)
   WHERE TABLENAME IN ('ADDSKULOG','UPDSKULOG') 
   AND   key1 = @c_StorerKey 
   AND transmitflag ='0'
   ORDER BY key3
   
   OPEN CUR_TRANSMITLOG3_LOOP
   
   FETCH FROM CUR_TRANSMITLOG3_LOOP INTO @c_TransmitLogKey, @c_SKU
   
   BEGIN TRAN
   
   WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
   BEGIN
      SET @c_BUSR7 = ''
      SET @c_SUSR2 = ''
      SET @c_BUSR4 = ''
      
      SELECT @c_BUSR7 = ISNULL(BUSR7, ''), 
             @c_SUSR2 = ISNULL(SUSR2, ''), 
             @c_BUSR4 = ISNULL(BUSR4, '')
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey 
      AND   Sku = @c_SKU 
      
      IF @c_BUSR7 <> '10'
      BEGIN
         DELETE FROM TRANSMITLOG3 
         WHERE transmitlogkey = @c_TransmitLogKey 

         SET @n_Err = @@ERROR        
                                     
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 13500
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                            ': Delete TRANSMITLOG3 Failed. (isp_Nike_SkuUpdate)'
         END
      END
      ELSE 
      BEGIN
      	IF @c_SUSR2 <> '' AND @c_BUSR4 <> '' 
      	BEGIN
      	   SET @c_Type = ''
      	   	
      	   SELECT @c_Type = c.Short 
      	   FROM CODELKUP AS c WITH(NOLOCK)
      	   WHERE  c.LISTNAME = 'SILHROUP' 
      	   AND    c.Code = @c_SUSR2
      	   AND    c.Storerkey = @c_Storerkey --NJOW02
      	       		
      	   IF @c_Type <> ''
      	   BEGIN
      	      SET @c_SUSR1 = ''
      	      
      	      SELECT @c_SUSR1 = ISNULL(c.Short,'') 
      	      FROM CODELKUP AS c WITH(NOLOCK)
      	      WHERE c.LISTNAME = 'APPAge'
      	      AND c.Code = @c_Type 
      	      AND c.code2 = @c_BUSR4
         	    AND c.Storerkey = @c_Storerkey --NJOW02
      	      
      	      IF @c_SUSR1 <> ''
      	      BEGIN
      	      	 UPDATE SKU WITH (ROWLOCK)  
      	      	 SET SUSR1 = @c_SUSR1, TrafficCop = NULL, EditDate = GETDATE()
      	      	 WHERE StorerKey = @c_StorerKey 
      	      	 AND   SKU = @c_SKU 

                 SET @n_Err = @@ERROR        
                                             
                 IF @n_Err <> 0
                 BEGIN
                    SET @n_Continue = 3
                    SET @n_Err = 13510
                    SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                    ': Update SKU Failed. (isp_Nike_SkuUpdate)'
                 END
      	      END
      	   END      	      
      	END   
      	
      	--NJOW01 
        UPDATE TRANSMITLOG3 WITH (ROWLOCK)
        SET transmitflag = '9'
        WHERE transmitlogkey = @c_TransmitLogKey 
        
        SET @n_Err = @@ERROR        
                                    
        IF @n_Err <> 0
        BEGIN
           SET @n_Continue = 3
           SET @n_Err = 13520
           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                           ': Update TRANSMITLOG3 Failed. (isp_Nike_SkuUpdate)'
        END         
      END
      	  
      FETCH FROM CUR_TRANSMITLOG3_LOOP INTO @c_TransmitLogKey, @c_SKU
   END
   CLOSE CUR_TRANSMITLOG3_LOOP
   DEALLOCATE CUR_TRANSMITLOG3_LOOP
  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_NIKE_SkuUpdate'      
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