SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/***************************************************************************/     
/* Modification History:                                                   */      
/*                                                                         */      
/* Called By:  Exceed                                                      */    
/*                                                                         */    
/* PVCS Version: 1.5                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Data Modifications: Getting Bartender Server and Printer Name           */    
/*                     based on Start Date                                 */  
/*                                                                         */    
/* Date         Author    Ver.  Purposes                                   */    
/***************************************************************************/        
CREATE PROC [dbo].[isp_GetBartenderPrintList] (  
   @d_StartDate DATETIME  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
  
   DECLARE @c_PrinterName NVARCHAR(200),  
           @c_ServerIP VARCHAR(20)   
  
   DECLARE @t_Printer TABLE ( ServerIP VARCHAR(20), PrinterName NVARCHAR(200))  
  
   DECLARE @cString NVARCHAR(MAX), @nStart INT, @nEnd INT  
  
   DECLARE CUR_PrintJob CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT   
      to1.RemoteEndPoint AS ServerIP,   
      LEFT(to1.[Data], 300)  
   FROM TCPSocket_OUTLog AS to1 WITH(NOLOCK)  
   WHERE to1.[Application]='bartender'  
   AND to1.RemoteEndPoint IS NOT NULL 
   AND to1.RemoteEndPoint > '0'  
   AND to1.AddDate > @d_StartDate  
   AND to1.[Data] IS NOT NULL 
   OPEN CUR_PrintJob  
  
   FETCH NEXT FROM CUR_PrintJob INTO @c_ServerIP, @cString  
   WHILE @@FETCH_STATUS = 0   
   BEGIN  
      SET @c_ServerIP = SUBSTRING(@c_ServerIP, 1, CHARINDEX(':',@c_ServerIP) - 1) 
      
      -- SET @cString = N'%BTW% /AF="C:\Users\Public\Documents\BarTender\TemplateFile\HK\WWMTv26(Yahei_sim_chi).btw" /PRN="HK_Lululemon_Datamax_I_4212eMarkII_001" /PrintJobName="lulu01HK_Lululemon_Datamax_I_4212eMarkII_001WWMTLBLLU202009010829412371" /R=3
      SET @nStart = 0   
      SET @nEnd =  0  
     
      SET @nStart = CHARINDEX('/PRN="',@cString) + 6  
      SET @nEnd = CHARINDEX('" /PrintJobName=',@cString)   
      
      IF @nStart > 6 AND @nEnd > 0 AND LEN(@cString) >= @nEnd
      BEGIN  
         SELECT @c_PrinterName = SUBSTRING(@cString, @nStart, @nEnd - @nStart)
            
         IF NOT EXISTS (SELECT 1 FROM @t_Printer AS tp   
                        WHERE tp.ServerIP = @c_ServerIP  
                        AND tp.PrinterName = @c_PrinterName)  
         BEGIN  
            INSERT INTO @t_Printer  
            (  
               ServerIP,  
               PrinterName  
            )  
            VALUES  
            (  
               @c_ServerIP,  
               @c_PrinterName  
            )  
         END  
           
      END  
      
      FETCH NEXT FROM CUR_PrintJob INTO @c_ServerIP, @cString  
   END  
   CLOSE CUR_PrintJob  
   DEALLOCATE CUR_PrintJob  
  
   SELECT @d_StartDate AS [RunDate], tp.ServerIP, tp.PrinterName  
     FROM @t_Printer AS tp    
     
END  
  

GO