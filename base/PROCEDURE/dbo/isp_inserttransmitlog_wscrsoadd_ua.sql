SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*-------------------------------------------------------------------------------------------------------------------*/            
/*                                                                                                                   */    
/*Stored Procedure: isp_InsertTransmitLog_WSCRSOADD_UA                                                               */                  
/* Creation Date: 22-February-201                                                                                    */                    
/* Copyright: LF LOGISTICS                                                                                           */                    
/* Written by: kelvinongcy                                                                                           */                    
/*                                                                                                                   */                    
/* Purpose: https://jira.lfapps.net/browse/WMS-7642                                                                  */                    
/*                                                                                                                   */                    
/* Called By: isp_OrdersMerging                                                                                      */                     
/*                                                                                                                   */                    
/* Parameters:                                                                                                       */                    
/*                                                                                                                   */                    
/* PVCS Version:                                                                                                     */                    
/*                                                                                                                   */                    
/* Version:                                                                                                          */                    
/*                                                                                                                   */                    
/* Data Modifications:                                                                                               */                    
/*                                                                                                                   */                    
/* Updates:                                                                                                          */                    
/* Date          Author      Ver. Purposes                                                                           */             
/* 22- Feb-2019  kocy        1.0  Insert TransmitLog3 for Storerkey ='UA' & tablename = 'WSCRSOADD'                  */    
/*                                and update Orders.Issued = 'Y' after UA Combined Orders job run                    */    
/* 17-May -2019  kocy        1.1  Insert TL2/TL3 based on UDF01 = T2/T3 when orders.ShipperKey = Codelkup.Short      */  
/*                                where listname = 'CourierMap', t.tablename = 'WSCRSOADD' (refer FBR ver 1.5)       */  
/* 24-May -2019  kocy01      1.2  Revise script                                                                      */  
/*                                Insert TL2/TL3 based on UDF01 = T2/T3 when orders.ShipperKey = Codelkup.Short      */  
/*                                where listname = 'CourierMap', t.tablename = Codelkup.UDF02(refer FBR ver 1.6)     */  
/* 07-Nov-2019  Shong        1.3  WMS-7642 - Enable JD to get tracking number (SWT01)                                */  
/* 09-Oct-2020  Josh         1.4  Split Order referance                                                              */
/*------------------------------------------------------------------------------------------------------------------*/     
    
CREATE PROCEDURE [dbo].[isp_InsertTransmitLog_WSCRSOADD_UA]   
(@c_StorerKey NVARCHAR(15) ,@b_debug BIT=0)  
AS  
 SET NOCOUNT ON                
 SET ANSI_NULLS OFF                
 SET QUOTED_IDENTIFIER OFF               
 SET CONCAT_NULL_YIELDS_NULL OFF             
 BEGIN  
     DECLARE @c_Orderkey          NVARCHAR(10)  
            ,@c_SValue            NVARCHAR(1)  
            ,@c_Key1              NVARCHAR(10)  
            ,@c_Key2              NVARCHAR(5)  
            ,@c_Key3              NVARCHAR(20)  
            ,@c_TransmitBatch     NVARCHAR(30)  
            ,@b_success           INT  
            ,@n_err               INT  
            ,@c_errmsg            NVARCHAR(250)  
            ,@n_continue          INT  
            ,@n_rowcount          INT  
            ,@c_UDF01             NVARCHAR(10)  
            ,@c_UDF02             NVARCHAR(25)  
       
     /********** Initial parameter values **************/                
     SELECT @c_SValue = NULL    
     SELECT @n_continue = 1  
           ,@b_success      = 0  
           ,@n_err          = ''  
           ,@n_rowcount     = 0    
       
       
     DECLARE @temp_CodelkupTable TABLE   
             (  
                 Code NVARCHAR(15)  
                ,Short NVARCHAR(15)  
                ,UDF01 NVARCHAR(10)  
                ,UDF02 NVARCHAR(25)  
             )   
       
     /********* StorerConfig checking *********/                        
       SET @c_SValue = '0' -- -- (SWT01)  
  
     SELECT @c_SValue = SVALUE  
     FROM   StorerConfig WITH (NOLOCK)  
     WHERE  ConfigKey     = 'WSCRSOADD_UA'  
     AND    Storerkey     = @c_StorerKey    
       
     IF (@c_SValue<>'1')  
     BEGIN  
        IF NOT EXISTS( SELECT 1   
                       FROM dbo.ITFTriggerConfig (nolock)   
                       WHERE StorerKey = @c_StorerKey   
                       AND Tablename IN ('WSCRSOADDJD') )  
        BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = N'FAIL MERGING. ConfigKey ''WSCRSOADD_UA'' for storerkey'''+@c_StorerKey   
               +''' is Turn OFF. Refer StorerConfig Table'           
        END  
           
         IF (@b_debug=1)  
         BEGIN  
             SELECT 'SVALUE = '+@c_SValue  
         END  
     END     
       
     IF (@n_continue=1 OR @n_continue=2)  
     BEGIN  
         -- (SWT01)  
        IF @c_SValue = '1' -- All Turn On  
        BEGIN  
            INSERT INTO @temp_CodelkupTable  
              ( [Code] ,[Short] ,[UDF01] ,[UDF02] )  
            SELECT [Code]  
                  ,[Short]  
                  ,[UDF01]  
                  ,[UDF02]  
            FROM   CODELKUP WITH (NOLOCK)  
            WHERE  LISTNAME = 'CourierMap'  
            AND    Storerkey = @c_Storerkey  
            AND    UDF01 IN ('T2' ,'T3')  
            ORDER BY [Code] ASC           
        END   
        ELSE   
        BEGIN  
            INSERT INTO @temp_CodelkupTable  
              ( [Code] ,[Short] ,[UDF01] ,[UDF02] )           
            SELECT CLK.[Code]  
                  ,CLK.[Short]  
                  ,CLK.[UDF01]  
                  ,CLK.[UDF02]  
            FROM   CODELKUP CLK WITH (NOLOCK)               
            WHERE  LISTNAME = 'CourierMap'  
            AND    Storerkey = @c_Storerkey  
            AND    UDF01 IN ('T2' ,'T3')   
            AND    EXISTS(SELECT 1   
                          FROM dbo.ITFTriggerConfig ITC (NOLOCK)   
                          WHERE ITC.StorerKey = CLK.Storerkey   
                          AND ITC.Tablename = CLK.UDF02    
                          AND ITC.TargetTable = 'TRANSMITLOG2'   
                          AND CLK.UDF01 = 'T2'                           
                          )    
            ORDER BY [Code] ASC               
        END  
           
         IF NOT EXISTS ( SELECT 1 FROM @temp_CodelkupTable )  
         BEGIN  
             SET @n_continue = 3                
             SET @c_errmsg = N'FAIL MERGING. No columns acquire from ''CODELKUP'' table. '  
         END  
           
         IF (@b_debug=1)  
         BEGIN  
             SELECT *  
             FROM   @temp_CodelkupTable  
         END  
           
         DECLARE CUR_T3 CURSOR LOCAL FAST_FORWARD READ_ONLY   
         FOR  
             SELECT o.Orderkey  
                   ,c.UDF01  
                   ,c.UDF02  
             FROM   ORDERS AS o WITH (NOLOCK)  
             JOIN @temp_CodelkupTable AS c ON (o.ShipperKey=c.Short)  
             WHERE  o.[SOStatus] = '0'  
             AND    TRY_CAST(o.[Status] AS INT)<=5  
             AND    o.StorerKey = @c_StorerKey  
             AND    o.DOCTYPE = 'E'  
             AND    o.Issued = 'N'  
             AND    o.OrderGroup <> 'CHILD_ORD'  
			 AND    o.OrderGroup <> 'SPLIT_ORD'   --Josh, split order's trackingno will get from original order
             AND    o.UserDefine04 = ''  
           
         OPEN CUR_T3   
         FETCH NEXT FROM CUR_T3 INTO @c_Orderkey, @c_UDF01, @c_UDF02   
           
         WHILE (@@FETCH_STATUS<>-1)  
         BEGIN  
             SET @b_success = 1    
               
             IF (@c_UDF01='T2')  
             BEGIN  
                 IF (@b_debug=1)  
                 BEGIN  
                     SELECT @c_Orderkey 'Orderkey'  
                         ,@c_UDF01 'UDF01'  
                           ,@c_UDF02 'TableName'  
                 END  
                   
                 -- Generate a unique key for TL2     
                 EXEC ispGenTransmitLog2 @c_UDF02  
                     ,@c_Orderkey  
                     ,@c_Key2  
                     ,@c_StorerKey  
                     ,@c_TransmitBatch  
                     ,@b_Success OUTPUT  
                     ,@n_err OUTPUT  
                     ,@c_errmsg OUTPUT   
                        
             END --(@c_UDF01 = 'T2')    
               
             IF (@c_UDF01='T3')  
             BEGIN  
                 IF (@b_debug=1)  
                 BEGIN  
                     SELECT @c_Orderkey 'Orderkey'  
                           ,@c_UDF01 'UDF01'  
                           ,@c_UDF02 'TableName'  
                 END  
                 -- Generate a unique key for TL3    
                 EXEC ispGenTransmitLog3 @c_UDF02  
                     ,@c_Orderkey  
                     ,@c_Key2  
                     ,@c_StorerKey  
                     ,@c_TransmitBatch  
                     ,@b_Success OUTPUT  
                     ,@n_err OUTPUT  
                     ,@c_errmsg OUTPUT   
                        
  
             END --IF (@c_UDF01 = 'T3')    
             FETCH NEXT FROM CUR_T3 INTO @c_Orderkey, @c_UDF01, @c_UDF02  
         END --(@@FETCH_STATUS <> -1)    
         CLOSE CUR_T3   
         DEALLOCATE CUR_T3       
  
QUIT:    
         IF CURSOR_STATUS('LOCAL' ,'CUR_T3 ') IN (0 ,1)  
         OR (@n_continue=3)  
         BEGIN  
             PRINT @c_errmsg   
             CLOSE CUR_T3   
             DEALLOCATE CUR_T3  
         END  
     END-- (@n_continue = 1 OR @n_continue = 2)  
 END 

GO