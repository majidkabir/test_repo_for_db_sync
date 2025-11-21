SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispBackendAssignTrackingNoByGroup                  */    
/* Creation Date: 13-Aug-2015                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By: Backend Schedule Job                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */  
/* 6June2017    TLTING  1.1   point to new ispAsgnTNo2                  */  
/* 20-Oct-2017  TLTING1 1.2   cater status < 5                          */
/* 12-Jul-2018  TLTING02 1.3  exclude sostatus by codelkup              */
/************************************************************************/    
CREATE PROC [dbo].[ispBackendAssignTrackingNoByGroup]  
     @d_StartDate   DATETIME 
   , @c_Group       NVARCHAR(60)  = ''
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0      
AS      
BEGIN      
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT, -- Holds the current transaction count  
            @c_OrderKey    NVARCHAR(10)   
  
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0    
   SELECT @c_ErrMsg=''               

   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN
              
   DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TOP 2000 O.OrderKey     
   FROM ORDERS O WITH (NOLOCK)  
   WHERE O.ShipperKey IS NOT NULL AND O.ShipperKey <> '' 
   AND   O.UserDefine04 = '' 
   AND   O.[Status] < '5'           --tlting1
   AND   O.sostatus <> 'PENDGET'    
   AND NOT EXISTS ( SELECT 1 FROM codelkup (NOLOCK) WHERE codelkup.LISTNAME = 'SOSTAXTNO' AND codelkup.code = O.sostatus ) --tlting02
   AND  EXISTS(SELECT 1 FROM CODELKUP AS clk WITH (NOLOCK)  
               WHERE  clk.Storerkey = O.StorerKey   
               AND   clk.Short = O.Shipperkey  
               AND   clk.Notes = O.Facility   
               AND   clk.LISTNAME = 'AsgnTNo'  
               AND   clk.code2 = '1'  
               AND   clk.Notes2 = @c_Group 
               AND   clk.UDF01 = CASE WHEN ISNULL(clk.UDF01,'') <> '' THEN ISNULL(o.UserDefine02,'') ELSE clk.UDF01 END  
               AND   clk.UDF02 = CASE WHEN ISNULL(clk.UDF02,'') <> '' THEN ISNULL(o.UserDefine03,'') ELSE clk.UDF02 END     
               AND   clk.UDF03 = CASE WHEN ISNULL(clk.UDF03,'') <> '' THEN ISNULL(o.[Type], '') ELSE clk.UDF03 END) 
   AND   O.AddDate > @d_StartDate 
   ORDER BY O.OrderKey
     
   OPEN CUR_ORDERKEY      
  
   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
    
   WHILE @@FETCH_STATUS <> -1          
   BEGIN         
      IF @b_debug = 1
      BEGIN
         PRINT '>>> Order# ' + @c_OrderKey
      END
      
      EXEC ispAsgnTNo2
         @c_OrderKey = @c_OrderKey,
         @c_LoadKey = '', 
         @b_Success = @b_Success OUTPUT,
         @n_Err     = @n_Err OUTPUT,
         @c_ErrMsg  = @c_ErrMsg OUTPUT,
         @b_debug   = @b_debug
      
      WHILE @@TRANCOUNT > 0 
         COMMIT TRAN 
            
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey         
   END -- WHILE @@FETCH_STATUS <> -1      
     
   CLOSE CUR_ORDERKEY          
 DEALLOCATE CUR_ORDERKEY    

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 
           
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispBackendAssignTrackingNoByGroup'      
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