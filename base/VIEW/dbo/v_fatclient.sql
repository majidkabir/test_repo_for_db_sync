SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_FatClient]      
AS       
SELECT       
   DATEPART(year,  login_date) As [Year],       
   DATEPART(month, login_date) As [Month],       
   Application,       
   COUNT(Distinct HostName) As FatClient       
FROM USER_CONNECTIONS WITH (NOLOCK)       
LEFT OUTER JOIN CODELKUP ON (CODELKUP.ListName = 'TSServer'       
                         AND CODELKUP.Code = USER_CONNECTIONS.Hostname)      
WHERE [Application] = 'WMS'      
AND   CODELKUP.Code IS NULL       
AND   login_name <> 'wmsgt'
and   HostName not in (
'IDS-WMS-UNG', 
'IDS-PFC-Leong',
'IDS-WMS-AUDREY',
'IDS-WMS-wtshong',
'IDS-WMS-vicky', 
'IDS-WMS-TTL',    
'IDS-WMS-leong', 
'IDS-WMS-njow',
'IDS-WMS-gtgoh', 
'IDS-WMS-ckp', 
'IDS-WMS-chinsp',
'IDS-GT-USER',  
'IDS-WMS-PHLEE', 
'ids-wmsrt-khlim', 
'ids-wms-ybyong', 
'IDS-WMS-MCTANG',
'IDS-GIT-NAZRUL', 
'IDS-RT-SCHUA',
'ids-git-ntan',
'IDS-GIT-CRYSTLE',
'IDS-GIT-PC',
'IDS-GIT-SUPPORT',
'IDS-WMS-SUPPORT',
'IDS-WMS-SUPPORT2',
'MYSLFA070133',
'MYSLFA060WMS',
'MYSLFA060146',
'MYSLFA070136',
'MYSLFA070166',
'MYSLFA070135',
'MYSLFA080287',
'MYSLFA080278',
'MYSLFA080316',
'MYSLFA110010',
'MYSLFA080500',
'MYSLFA080096b',
'MYSLFA080001',
'MYSLFA080132',
'MYSLFA080101',
'MYSLFA080097',
'MYSLFA080109',
'MYSLFA08GIT01',
'MYSLFA08MCT',
'MYSLFA110101',
'MYSLFA110116'
  )    
GROUP BY       
   DATEPART(month, login_date),       
   DATEPART(year,  login_date),      
   Application       
 


GO